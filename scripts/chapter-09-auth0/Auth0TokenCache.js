/**
 * Script 9-3: Auth0 M2M Token Cache Pattern
 * Production-ready M2M token caching class.
 * Auth0 charges per M2M token issuance — uncached services generate thousands of tokens/hour.
 *
 * Features:
 *   - In-memory cache with TTL tracking
 *   - 60-second pre-expiry refresh to avoid last-second expiration
 *   - Thread-safe for concurrent async requests (single in-flight request)
 *
 * Chapter 9 §9.5 — M2M Client Credentials
 *
 * Usage:
 *   const cache = new Auth0TokenCache({
 *     domain:       'yourco.auth0.com',
 *     clientId:     'YOUR_CLIENT_ID',
 *     clientSecret: process.env.AUTH0_CLIENT_SECRET,
 *     audience:     'https://api.yourapp.com',
 *   });
 *   const token = await cache.getToken();
 */

const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

class Auth0TokenCache {
  /**
   * @param {Object} config
   * @param {string} config.domain        - Auth0 domain (yourco.auth0.com)
   * @param {string} config.clientId      - M2M application client ID
   * @param {string} config.clientSecret  - M2M application client secret
   * @param {string} config.audience      - API audience (resource server identifier)
   * @param {number} [config.preExpiryBuffer=60] - Seconds before expiry to refresh
   */
  constructor({ domain, clientId, clientSecret, audience, preExpiryBuffer = 60 }) {
    this._tokenUrl      = `https://${domain}/oauth/token`;
    this._clientId      = clientId;
    this._clientSecret  = clientSecret;
    this._audience      = audience;
    this._preExpiry     = preExpiryBuffer;

    this._cachedToken   = null;
    this._expiresAt     = null;
    this._inflightRequest = null;  // Prevents concurrent token requests
  }

  /**
   * Returns a valid access token, using cache when possible.
   * @returns {Promise<string>} Access token
   */
  async getToken() {
    // Use cached token if still valid (with pre-expiry buffer)
    if (this._cachedToken && this._expiresAt && Date.now() < this._expiresAt - (this._preExpiry * 1000)) {
      return this._cachedToken;
    }

    // If there's already a request in flight, wait for it (avoid stampede)
    if (this._inflightRequest) {
      return this._inflightRequest;
    }

    // Fetch new token
    this._inflightRequest = this._fetchToken().finally(() => {
      this._inflightRequest = null;
    });

    return this._inflightRequest;
  }

  async _fetchToken() {
    const requestTime = Date.now();
    console.log(`[TokenCache] Requesting new token from Auth0 (cache miss)...`);

    const response = await fetch(this._tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type:    'client_credentials',
        client_id:     this._clientId,
        client_secret: this._clientSecret,
        audience:      this._audience,
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`Token request failed: ${response.status} - ${err}`);
    }

    const data = await response.json();

    this._cachedToken = data.access_token;
    this._expiresAt   = requestTime + (data.expires_in * 1000);

    const expiresIn   = Math.floor(data.expires_in / 60);
    const refreshAt   = Math.floor((data.expires_in - this._preExpiry) / 60);
    console.log(`[TokenCache] Token cached. Expires in ${expiresIn}min. Will refresh after ${refreshAt}min.`);

    return this._cachedToken;
  }

  /** Returns cache status for monitoring/debugging */
  status() {
    const ttl = this._expiresAt ? Math.floor((this._expiresAt - Date.now()) / 1000) : 0;
    return {
      cached:     !!this._cachedToken,
      expiresInSec: ttl,
      willRefreshInSec: Math.max(0, ttl - this._preExpiry),
    };
  }

  /** Force cache invalidation (e.g., on 401 response from downstream API) */
  invalidate() {
    console.log('[TokenCache] Cache invalidated — next call will fetch new token');
    this._cachedToken = null;
    this._expiresAt   = null;
  }
}

// --- Demo: simulate 10 concurrent API calls ---
(async () => {
  const cache = new Auth0TokenCache({
    domain:       process.env.AUTH0_DOMAIN       || 'yourco.auth0.com',
    clientId:     process.env.AUTH0_CLIENT_ID    || 'your-client-id',
    clientSecret: process.env.AUTH0_CLIENT_SECRET || 'your-client-secret',
    audience:     process.env.AUTH0_AUDIENCE     || 'https://api.yourapp.com',
  });

  console.log('\n=== M2M Token Cache Demo (10 simulated calls) ===');
  const tokens = await Promise.all(Array.from({ length: 10 }, () => cache.getToken().catch(e => `ERROR: ${e.message}`)));

  const unique = new Set(tokens.filter(t => !t.startsWith('ERROR')));
  console.log(`\nResult: ${tokens.length} calls, ${unique.size} unique token(s) (should be 1)`);
  console.log('Cache status:', cache.status());
})();

module.exports = Auth0TokenCache;
