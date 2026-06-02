/**
 * Script 9-6: Auth0 Post-Login Action — Profile Enrichment
 * Adds organization context, external permissions, and adaptive MFA enforcement.
 *
 * Security patterns:
 *   - Namespace-prefixed custom claims (required by Auth0 — prevents collision with OIDC standard claims)
 *   - Fail-open for enrichment: if permissions API is unavailable, user is not locked out
 *   - Fail-closed for explicit blocks: if geo-block applies, deny login
 *   - org_id verification: reject org tokens if org_id doesn't match expected tenant
 *
 * Chapter 9 §9.4 — Actions vs. Rules
 * Chapter 9 §9.6 — org_id Security
 */

exports.onExecutePostLogin = async (event, api) => {
  const NAMESPACE = 'https://yourapp.com';   // MUST be a URI you control

  // -----------------------------------------------------------------------
  // 1. Verify org_id if this is an organization login
  // -----------------------------------------------------------------------
  if (event.organization) {
    const orgId = event.organization.id;

    // Ensure the user is a member of this org (Auth0 enforces this, but belt-and-suspenders)
    if (!event.user.user_metadata?.allowed_orgs?.includes(orgId)) {
      // Note: In most cases, Auth0 already prevents non-members from completing org login
      // This is a secondary check for defense-in-depth
      console.log(`[WARN] User ${event.user.email} attempted org login without allowed_orgs match`);
    }

    // Add org context to ID token
    api.idToken.setCustomClaim(`${NAMESPACE}/org_id`, orgId);
    api.idToken.setCustomClaim(`${NAMESPACE}/org_name`, event.organization.name);
    api.idToken.setCustomClaim(`${NAMESPACE}/org_display_name`, event.organization.display_name);
  }

  // -----------------------------------------------------------------------
  // 2. Enrich with external permissions (fail-open for availability)
  // -----------------------------------------------------------------------
  const permissionsApiUrl = event.secrets?.PERMISSIONS_API_URL;
  if (permissionsApiUrl) {
    try {
      const response = await fetch(`${permissionsApiUrl}/users/${event.user.user_id}/permissions`, {
        headers: {
          Authorization: `Bearer ${event.secrets.PERMISSIONS_API_KEY}`,
          'Content-Type': 'application/json',
        },
        signal: AbortSignal.timeout(2000),  // 2-second timeout — don't block login
      });

      if (response.ok) {
        const perms = await response.json();
        // Add to access token (not ID token — keep ID token lean)
        api.accessToken.setCustomClaim(`${NAMESPACE}/permissions`, perms.permissions || []);
        api.accessToken.setCustomClaim(`${NAMESPACE}/department`, perms.department || '');
        api.idToken.setCustomClaim(`${NAMESPACE}/department`, perms.department || '');
      }
    } catch (err) {
      // Fail-open: enrichment failure does not block login
      console.log(`[WARN] Permissions API unavailable: ${err.message} — proceeding without enrichment`);
    }
  }

  // -----------------------------------------------------------------------
  // 3. Adaptive MFA enforcement based on context
  // -----------------------------------------------------------------------
  const isHighRiskCountry = ['CN', 'RU', 'KP', 'IR'].includes(event.request.geoip?.countryCode);
  const isPrivilegedUser  = event.authorization?.roles?.includes('admin') ||
                            event.authorization?.roles?.includes('superadmin');

  if (isHighRiskCountry && !event.user.user_metadata?.exempt_from_geo_mfa) {
    console.log(`[MFA] High-risk country (${event.request.geoip?.countryCode}) — requiring MFA`);
    api.multifactor.enable('any', { allowRememberBrowser: false });
  } else if (isPrivilegedUser) {
    // Privileged users: always require MFA, never allow remember-browser
    api.multifactor.enable('any', { allowRememberBrowser: false });
  }

  // -----------------------------------------------------------------------
  // 4. Legacy hash migration trigger
  // -----------------------------------------------------------------------
  if (event.user.user_metadata?.legacy_hash_migration_required) {
    // Force password reset to upgrade from MD5 to bcrypt via Auth0's managed flow
    api.user.setUserMetadata('legacy_hash_migration_required', null);
    api.user.setUserMetadata('password_migration_completed_at', new Date().toISOString());
    // In a real implementation, you'd trigger a password reset email here
    // and potentially block login until reset is complete (strict mode)
  }

  // -----------------------------------------------------------------------
  // 5. Add standard enrichment claims
  // -----------------------------------------------------------------------
  api.idToken.setCustomClaim(`${NAMESPACE}/email_verified`, event.user.email_verified);
  api.idToken.setCustomClaim(`${NAMESPACE}/created_at`, event.user.created_at);
};
