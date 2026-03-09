output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets-1" {
  value = aws_subnet.public[0].id
}

output "public_subnets-2" {
  value = aws_subnet.public[1].id
}

output "private_subnets-1" {
  value = aws_subnet.private[0].id
}

output "private_subnets-2" {
  value = aws_subnet.private[1].id
}

output "private_subnets-3" {
  value = aws_subnet.private[2].id
}

output "private_subnets-4" {
  value = aws_subnet.private[3].id
}

output "internet_gateway" {
  value = aws_internet_gateway.ig.id
}
output "nat_gateway_ip" {
  value = aws_eip.nat_eip.public_ip
}