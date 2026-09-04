module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "cert-manager-role"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [var.hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.eks.outputs.oidc_provider_arn
      namespace_service_accounts = ["${var.cert_manager_namespace}:cert-manager"]
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
