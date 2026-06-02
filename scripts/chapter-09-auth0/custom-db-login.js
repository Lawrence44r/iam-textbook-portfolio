/**
 * Script 9-4: Auth0 Custom Database Login Script
 * Supports lazy migration from legacy user store.
 * Handles bcrypt (current) and MD5-salted (legacy) password hashing.
 *
 * This script runs inside Auth0's Action sandbox — no npm imports available.
 * Use only built-in Node.js modules and Auth0-provided libraries.
 *
 * Chapter 9 §9.8 — Custom Database + Lazy Migration
 * Chapter 9 §9.14 — Lab 9-D
 */

function login(email, password, callback) {
  // Auth0 provides these in the Custom Database sandbox
  const bcrypt    = require('bcrypt');
  const crypto    = require('crypto');
  const mysql     = require('mysql');  // Or use your DB driver of choice

  const connection = mysql.createConnection({
    host:     configuration.DB_HOST,
    user:     configuration.DB_USER,
    password: configuration.DB_PASSWORD,
    database: configuration.DB_NAME,
  });

  connection.connect();

  const query = 'SELECT id, email, password_hash, hash_type, is_active FROM users WHERE email = ? LIMIT 1';

  connection.query(query, [email], function(err, results) {
    connection.end();

    if (err) return callback(err);
    if (results.length === 0) return callback(new WrongUsernameOrPasswordError(email));

    const user = results[0];

    if (!user.is_active) {
      return callback(new Error('Account is disabled'));
    }

    // Determine hashing algorithm from stored hash_type column
    const hashType = user.hash_type || 'bcrypt';

    if (hashType === 'bcrypt') {
      // Modern bcrypt hash — direct comparison
      bcrypt.compare(password, user.password_hash, function(err, isMatch) {
        if (err) return callback(err);
        if (!isMatch) return callback(new WrongUsernameOrPasswordError(email));

        // Return Auth0 user profile
        return callback(null, buildUserProfile(user));
      });

    } else if (hashType === 'md5_salted') {
      // Legacy MD5+salt hash — verify, then trigger password migration
      // Format: hash_type=md5_salted, stored as: MD5(salt + password)
      const [storedSalt, storedHash] = user.password_hash.split(':');
      const candidateHash = crypto
        .createHash('md5')
        .update(storedSalt + password)
        .digest('hex');

      if (candidateHash !== storedHash) {
        return callback(new WrongUsernameOrPasswordError(email));
      }

      // Password is correct — user needs to be migrated to bcrypt
      // We set a custom claim that a Post-Login Action will detect
      const profile = buildUserProfile(user);
      profile.user_metadata = {
        ...profile.user_metadata,
        legacy_hash_migration_required: true,  // Action will force password reset
      };
      return callback(null, profile);

    } else {
      return callback(new Error(`Unknown hash type: ${hashType}`));
    }
  });
}

function buildUserProfile(user) {
  return {
    user_id:  `legacy|${user.id}`,    // Deterministic ID for idempotent migration
    email:    user.email,
    email_verified: true,             // Assume verified in legacy system
    user_metadata: {
      migrated_from: 'legacy_db',
      migrated_at:   new Date().toISOString(),
    },
  };
}
