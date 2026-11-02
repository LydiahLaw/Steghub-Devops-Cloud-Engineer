#!/usr/bin/env bash
# Configures Vault for the tooling app. Run once after `vault operator init`,
# with VAULT_ADDR set and VAULT_TOKEN set to the initial root token.
# Safe to re-run: existing mounts and auth methods are left in place.
set -euo pipefail
cd "$(dirname "$0")"

: "${VAULT_ADDR:?Set VAULT_ADDR}"
: "${VAULT_TOKEN:?Set VAULT_TOKEN (root token, first run only)}"
: "${VAULT_ADMIN_PASSWORD:?Set VAULT_ADMIN_PASSWORD for the scoped admin login}"

echo "1. KV v2 secrets engine at app/"
vault secrets list | grep -q '^app/' || vault secrets enable -path=app kv-v2

echo "2. Kubernetes auth method"
vault auth list | grep -q '^kubernetes/' || vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc:443"

echo "3. One policy and one role per environment"
for env in dev sit prod; do
  vault policy write "tooling-${env}" "policies/tooling-${env}.hcl"
  vault write "auth/kubernetes/role/tooling-${env}" \
    bound_service_account_names=tooling-sa \
    bound_service_account_namespaces="${env}-tooling" \
    policies="tooling-${env}" \
    ttl=1h
done

echo "4. Remove the old shared role and wildcard policy"
vault delete auth/kubernetes/role/tooling-role >/dev/null 2>&1 || true
vault policy delete tooling-db >/dev/null 2>&1 || true

echo "5. Scoped admin login"
vault auth list | grep -q '^userpass/' || vault auth enable userpass
vault policy write vault-admin policies/vault-admin.hcl
vault write auth/userpass/users/admin password="${VAULT_ADMIN_PASSWORD}" token_policies=vault-admin token_ttl=1h

echo "Done. Log in with: vault login -method=userpass username=admin"
echo "Then revoke the root token: vault token revoke <root-token>"
