output "alb_dns_name" {
  description = "DNS name of the external Application Load Balancer"
  value       = aws_lb.ext-alb.dns_name
}

output "alb_target_group_arn" {
  description = "ARN of the Nginx target group"
  value       = aws_lb_target_group.nginx-tgt.arn
}

output "vpc_id" {
  description = "The ID of the main VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}
