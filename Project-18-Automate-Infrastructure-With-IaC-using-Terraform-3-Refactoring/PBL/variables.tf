variable "region" {
  type        = string
  description = "The region to deploy resources"
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The VPC CIDR block"
  default     = "172.16.0.0/16"
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "preferred_number_of_public_subnets" {
  type        = number
  description = "Number of public subnets"
  default     = 2
}

variable "preferred_number_of_private_subnets" {
  type        = number
  description = "Number of private subnets"
  default     = 4
}

variable "name" {
  type    = string
  default = "ACS"
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "ami" {
  type        = string
  description = "AMI ID for the launch templates"
}

variable "keypair" {
  type        = string
  description = "Key pair name for EC2 instances"
}

variable "account_no" {
  type        = string
  description = "Your AWS account number"
}

variable "master_username" {
  type        = string
  description = "RDS admin username"
}

variable "master_password" {
  type        = string
  description = "RDS admin password"
  sensitive   = true
}

variable "images" {
  type        = map(string)
  description = "AMI IDs per region"
  default = {
    eu-central-1 = "ami-0c42fad2ea005202d"
    us-east-1    = "ami-0c55b159cbfafe1f0"
    us-west-2    = "ami-0fcf52bcf5db7b003"
  }
}