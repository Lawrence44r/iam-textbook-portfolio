#!/usr/bin/env bash
# Script 9-7: Auth0 Tenant-as-Code Deployment
# Uses Auth0 Deploy CLI for GitOps-style tenant configuration management.
# Chapter 9 §9.9 — Deployment Models / Tenant-as-Code

set -euo pipefail

# Environment variables required:
# AUTH0_DOMAIN       - your-tenant.auth0.com
# AUTH0_CLIENT_ID    - Deploy CLI M2M application client ID
# AUTH0_CLIENT_SECRET - Deploy CLI M2M application client secret
# ENV               - dev | staging | prod

ENV="${ENV:-dev}"

if [[ -z "${AUTH0_DOMAIN:-}" || -z "${AUTH0_CLIENT_ID:-}" || -z "${AUTH0_CLIENT_SECRET:-}" ]]; then
  echo "[ERROR] Set AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET"
  exit 1
fi

# Determine config directory based on environment
CONFIG_DIR="./tenant-config"
ENV_FILE="./tenant-config/environments/${ENV}.env.json"

echo "========================================"
echo "  Auth0 Tenant Deployment"
echo "  Environment: $ENV"
echo "  Domain: $AUTH0_DOMAIN"
echo "========================================"

# -----------------------------------------------------------------------
# EXPORT — Capture current tenant state to YAML
# -----------------------------------------------------------------------
export_tenant() {
  echo ""
  echo "[EXPORT] Exporting current tenant config from $AUTH0_DOMAIN..."
  a0deploy export \
    --config_file "$ENV_FILE" \
    --format yaml \
    --output_folder "$CONFIG_DIR" \
    --strip_keywords
  echo "[EXPORT] Done. Review changes with: git diff $CONFIG_DIR/"
}

# -----------------------------------------------------------------------
# IMPORT — Apply YAML config to tenant
# -----------------------------------------------------------------------
import_tenant() {
  echo ""
  echo "[IMPORT] Applying config to $AUTH0_DOMAIN ($ENV)..."

  # Dry-run first (validate)
  echo "[IMPORT] Validating (dry-run)..."
  a0deploy import \
    --config_file "$ENV_FILE" \
    --input_file "$CONFIG_DIR" \
    --dry-run

  if [[ "${FORCE:-false}" != "true" ]]; then
    read -r -p "[IMPORT] Dry-run complete. Apply to $AUTH0_DOMAIN? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi

  a0deploy import \
    --config_file "$ENV_FILE" \
    --input_file "$CONFIG_DIR"

  echo "[IMPORT] Deployment complete."
}

# -----------------------------------------------------------------------
# DIFF — Show what would change
# -----------------------------------------------------------------------
diff_tenant() {
  echo ""
  echo "[DIFF] Comparing local config to live tenant $AUTH0_DOMAIN..."
  a0deploy export \
    --config_file "$ENV_FILE" \
    --format yaml \
    --output_folder "/tmp/auth0-export-$ENV" \
    --strip_keywords 2>/dev/null
  diff -r "$CONFIG_DIR" "/tmp/auth0-export-$ENV" || true
  rm -rf "/tmp/auth0-export-$ENV"
}

# -----------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------
case "${1:-help}" in
  export)  export_tenant ;;
  import)  import_tenant ;;
  diff)    diff_tenant   ;;
  *)
    echo "Usage: ENV=dev AUTH0_DOMAIN=... AUTH0_CLIENT_ID=... AUTH0_CLIENT_SECRET=... $0 [export|import|diff]"
    echo ""
    echo "  export  — Download current live tenant config to YAML"
    echo "  import  — Apply local YAML config to tenant (with dry-run)"
    echo "  diff    — Show difference between local config and live tenant"
    echo ""
    echo "Set FORCE=true to skip confirmation prompt on import."
    ;;
esac
