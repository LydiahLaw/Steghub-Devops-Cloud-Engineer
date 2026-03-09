terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "lydiah-dev-terraform-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

module "VPC" {
  source                              = "./modules/VPC"
  vpc_cidr                            = var.vpc_cidr
  enable_dns_support                  = var.enable_dns_support
  enable_dns_hostnames                = var.enable_dns_hostnames
  preferred_number_of_public_subnets  = var.preferred_number_of_public_subnets
  preferred_number_of_private_subnets = var.preferred_number_of_private_subnets
  availability_zones                  = data.aws_availability_zones.available.names
  tags                                = var.tags
}

module "security" {
  source = "./modules/security"
  vpc_id = module.VPC.vpc_id
  tags   = var.tags
}

module "ALB" {
  source          = "./modules/ALB"
  vpc_id          = module.VPC.vpc_id
  public_subnets  = [module.VPC.public_subnets-1, module.VPC.public_subnets-2]
  private_subnets = [module.VPC.private_subnets-1, module.VPC.private_subnets-2]
  ALB_sg          = module.security.ALB_sg
  internal_alb_sg = module.security.internal_alb_sg
  tags            = var.tags
}

module "autoscaling" {
  source             = "./modules/autoscaling"
  ami                = var.ami
  keypair            = var.keypair
  bastion_sg         = module.security.bastion_sg
  nginx_sg           = module.security.nginx_sg
  webserver_sg       = module.security.webserver_sg
  public_subnets     = [module.VPC.public_subnets-1, module.VPC.public_subnets-2]
  private_subnets    = [module.VPC.private_subnets-1, module.VPC.private_subnets-2]
  nginx_alb_tgt      = module.ALB.alb_target_group_arn
  wordpress_alb_tgt  = module.ALB.wordpress_tgt_arn
  tooling_alb_tgt    = module.ALB.tooling_tgt_arn
  instance_profile   = aws_iam_instance_profile.ip.name
  availability_zones = data.aws_availability_zones.available.names
  tags               = var.tags
}

module "EFS" {
  source         = "./modules/EFS"
  subnet_ids     = [module.VPC.private_subnets-3, module.VPC.private_subnets-4]
  security_group = module.security.datalayer_sg
  account_no     = var.account_no
  tags           = var.tags
}

module "RDS" {
  source          = "./modules/RDS"
  private_subnets = [module.VPC.private_subnets-3, module.VPC.private_subnets-4]
  datalayer_sg    = module.security.datalayer_sg
  master_username = var.master_username
  master_password = var.master_password
  tags            = var.tags
}