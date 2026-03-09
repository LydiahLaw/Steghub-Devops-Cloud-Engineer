output "alb_dns_name" {
  description = "DNS name of the external Application Load Balancer"
  value       = module.ALB.alb_dns_name
}

output "alb_target_group_arn" {
  description = "ARN of the Nginx target group"
  value       = module.ALB.alb_target_group_arn
}

output "vpc_id" {
  description = "The ID of the main VPC"
  value       = module.VPC.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [module.VPC.public_subnets-1, module.VPC.public_subnets-2]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [module.VPC.private_subnets-1, module.VPC.private_subnets-2, module.VPC.private_subnets-3, module.VPC.private_subnets-4]
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = module.VPC.nat_gateway_ip
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks.name
}