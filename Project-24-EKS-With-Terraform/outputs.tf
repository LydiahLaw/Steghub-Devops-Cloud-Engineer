output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_region" {
  description = "AWS region the cluster runs in"
  value       = "us-west-1"
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider associated with this cluster (needed for IRSA trust policies)"
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL for the cluster (without the https:// scheme), used in IRSA trust policy conditions"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}
output "vpc_id" {
  description = "VPC ID, used by Project 27 to place Aurora in the same network"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs, used for the Aurora DB subnet group"
  value       = module.vpc.private_subnets
}

output "vpc_cidr_block" {
  description = "VPC CIDR, used to allow MySQL traffic from inside the VPC"
  value       = module.vpc.vpc_cidr_block
}
