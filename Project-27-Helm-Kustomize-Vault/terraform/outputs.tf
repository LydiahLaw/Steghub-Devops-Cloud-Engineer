output "vault_kms_key_arn" {
  value = module.vault_kms_key.key_arn
}

output "vault_irsa_role_arn" {
  value = module.vault_irsa.iam_role_arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.tooling_app.repository_url
}

output "aurora_endpoint" {
  value = aws_rds_cluster.tooling.endpoint
}

output "aurora_master_username" {
  value = aws_rds_cluster.tooling.master_username
}

output "aurora_master_password" {
  value     = random_password.aurora_master.result
  sensitive = true
}
