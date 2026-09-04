# Pulls Project 24's outputs (cluster endpoint, CA cert, OIDC provider ARN)
# directly from its remote state, instead of hardcoding values that break
# the moment the cluster is rebuilt.
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "lydiah-eks-terraform-state"
    key    = "eks/terraform.tfstate"
    region = "us-west-1"
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}
