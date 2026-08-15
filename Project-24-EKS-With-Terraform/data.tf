# get all available AZs in our region
data "aws_availability_zones" "available_azs" {
  state = "available"
}

data "aws_caller_identity" "current" {} # used for accessing Account ID and ARN

# get EKS cluster auth token to configure the Kubernetes and Helm providers
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}