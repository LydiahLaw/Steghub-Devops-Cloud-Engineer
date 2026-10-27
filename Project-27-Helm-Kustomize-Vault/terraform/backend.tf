terraform {
  required_version = "~> 1.11"

  backend "s3" {
    bucket       = "lydiah-eks-terraform-state"
    key          = "project27/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
