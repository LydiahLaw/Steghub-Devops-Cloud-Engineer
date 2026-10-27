resource "aws_iam_policy" "vault_kms" {
  name        = "VaultKMSUnseal"
  description = "Allows Vault to use the KMS key for auto-unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
      Resource = module.vault_kms_key.key_arn
    }]
  })
}

module "vault_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "vaultKMS"

  role_policy_arns = {
    vault_kms = aws_iam_policy.vault_kms.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = local.eks.oidc_provider_arn
      namespace_service_accounts = ["vault:vault-kms"]
    }
  }
}
