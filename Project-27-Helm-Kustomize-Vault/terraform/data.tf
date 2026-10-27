data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "lydiah-eks-terraform-state"
    key    = "eks/terraform.tfstate"
    region = "us-west-1"
  }
}

locals {
  eks = data.terraform_remote_state.eks.outputs
}
