module "vault_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.1"

  description             = "Vault Cluster KMS Key"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  aliases                 = ["dev-vault-kms"]
}
