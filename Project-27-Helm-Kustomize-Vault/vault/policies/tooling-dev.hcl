# dev tooling app: read its own database config only
path "app/data/database/config/dev" {
  capabilities = ["read"]
}
