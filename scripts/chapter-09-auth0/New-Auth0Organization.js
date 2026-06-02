/**
 * Script 9-1: Auth0 Organization Provisioning
 * Provisions a new Auth0 Organization for a B2B SaaS customer.
 * Actions: Create org → enable connections → create default roles → send admin invitation.
 * Chapter 9 §9.6 — Organizations (org_id Security)
 *
 * Usage:
 *   AUTH0_DOMAIN=yourco.auth0.com AUTH0_MGMT_TOKEN=<token> node New-Auth0Organization.js
 */

const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

const DOMAIN    = process.env.AUTH0_DOMAIN;
const MGMT_TOKEN = process.env.AUTH0_MGMT_TOKEN;

if (!DOMAIN || !MGMT_TOKEN) {
  console.error('[ERROR] Set AUTH0_DOMAIN and AUTH0_MGMT_TOKEN environment variables');
  process.exit(1);
}

const BASE = `https://${DOMAIN}/api/v2`;

async function auth0Request(method, path, body = null) {
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${MGMT_TOKEN}`,
      'Content-Type': 'application/json',
    },
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${BASE}${path}`, opts);
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) throw new Error(`Auth0 API ${method} ${path} → ${res.status}: ${JSON.stringify(data)}`);
  return data;
}

/**
 * Provision a new Auth0 Organization.
 * @param {Object} opts
 * @param {string} opts.customerSlug    - URL-safe org identifier (e.g. "acme-corp")
 * @param {string} opts.companyName     - Display name
 * @param {string} opts.logoUrl         - Logo URL for Universal Login branding
 * @param {string} opts.primaryColor    - Hex color (e.g. "#0A74DA")
 * @param {string} opts.adminEmail      - First admin to invite
 * @param {string} opts.connectionId    - Auth0 connection to enable for this org
 * @param {string} opts.invitationRoleId - Auth0 role ID to grant admin
 */
async function provisionOrganization(opts) {
  const { customerSlug, companyName, logoUrl, primaryColor, adminEmail, connectionId, invitationRoleId } = opts;

  console.log(`\n=== Provisioning Auth0 Organization: ${companyName} (${customerSlug}) ===`);

  // Step 1: Create organization
  console.log('Step 1: Creating organization...');
  const org = await auth0Request('POST', '/organizations', {
    name:         customerSlug,
    display_name: companyName,
    branding: {
      logo_url: logoUrl,
      colors:   { primary: primaryColor, page_background: '#ffffff' },
    },
    metadata: {
      provisioned_at: new Date().toISOString(),
      plan:           opts.plan || 'standard',
      seats:          String(opts.seats || 25),
    },
  });
  console.log(`  ✓ Organization created: ${org.id}`);

  // Step 2: Enable connection for this org
  if (connectionId) {
    console.log('Step 2: Enabling connection...');
    await auth0Request('POST', `/organizations/${org.id}/enabled_connections`, {
      connection_id:            connectionId,
      assign_membership_on_login: false,  // Don't auto-add all connection users to org
    });
    console.log(`  ✓ Connection enabled: ${connectionId}`);
  }

  // Step 3: Send admin invitation
  console.log('Step 3: Sending admin invitation...');
  const invitation = await auth0Request('POST', `/organizations/${org.id}/invitations`, {
    inviter:   { name: 'Platform Admin' },
    invitee:   { email: adminEmail },
    client_id: process.env.AUTH0_CLIENT_ID || '',  // Your SPA/web app client_id
    roles:     invitationRoleId ? [invitationRoleId] : [],
    ttl_sec:   604800,  // 7 days
    send_invitation_email: true,
  });
  console.log(`  ✓ Invitation sent to ${adminEmail} (expires in 7 days)`);
  console.log(`  Invitation ID: ${invitation.id}`);

  console.log(`\n✓ Organization provisioned successfully`);
  console.log(`  Org ID:   ${org.id}`);
  console.log(`  Org Name: ${org.name}`);
  console.log(`  Admin:    ${adminEmail}`);

  return { org, invitation };
}

// --- Example usage ---
provisionOrganization({
  customerSlug:     'acme-corp',
  companyName:      'Acme Corporation',
  logoUrl:          'https://cdn.acme.com/logo.png',
  primaryColor:     '#0A74DA',
  adminEmail:       'admin@acme.com',
  connectionId:     process.env.AUTH0_CONNECTION_ID || '',
  invitationRoleId: process.env.AUTH0_ORG_ADMIN_ROLE_ID || '',
  plan:             'enterprise',
  seats:            100,
}).catch(err => {
  console.error(`[ERROR] ${err.message}`);
  process.exit(1);
});
