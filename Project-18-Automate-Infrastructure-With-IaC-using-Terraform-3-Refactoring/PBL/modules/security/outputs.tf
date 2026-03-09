output "ALB_sg" {
  value = aws_security_group.ext-alb-sg.id
}

output "bastion_sg" {
  value = aws_security_group.bastion_sg.id
}

output "nginx_sg" {
  value = aws_security_group.nginx-sg.id
}

output "internal_alb_sg" {
  value = aws_security_group.int-alb-sg.id
}

output "webserver_sg" {
  value = aws_security_group.webserver-sg.id
}

output "datalayer_sg" {
  value = aws_security_group.datalayer-sg.id
}