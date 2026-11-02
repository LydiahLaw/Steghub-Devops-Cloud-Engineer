# prod tooling app: read its own database config only
path "app/data/database/config/prod" {
  capabilities = ["read"]
}
