# Scoped admin for day-to-day work after bootstrap (replaces the root token)

# Manage application secrets
path "app/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "app/metadata/*" {
  capabilities = ["read", "list", "delete"]
}

# Manage Kubernetes auth roles and config
path "auth/kubernetes/role/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/kubernetes/config" {
  capabilities = ["read", "update"]
}

# Manage the tooling policies only, not admin or root policies
path "sys/policies/acl/tooling-*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/policies/acl" {
  capabilities = ["list"]
}

# Read-only visibility of mounts, auth methods and health
path "sys/mounts" {
  capabilities = ["read"]
}
path "sys/auth" {
  capabilities = ["read"]
}
