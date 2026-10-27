provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "project-27-helm-kustomize-vault"
      Terraform = "true"
    }
  }
}
