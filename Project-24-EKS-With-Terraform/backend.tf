# Configure the backend to store state remotely in S3
# Replace the bucket name below with the one you create in Step 2 (must be globally unique)

terraform {
  required_version = "~> 1.11"   # use_lockfile needs 1.11+ to be GA (it was experimental in 1.10)

  backend "s3" {
    bucket       = "lydiah-eks-terraform-state"   # <-- replace with YOUR bucket name
    key          = "eks/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true    # native S3 state locking — no DynamoDB table needed
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}
