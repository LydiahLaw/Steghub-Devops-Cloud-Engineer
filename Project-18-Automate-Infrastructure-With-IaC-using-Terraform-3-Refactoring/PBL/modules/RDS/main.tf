# RDS Subnet Group — tells RDS which subnets it can use
resource "aws_db_subnet_group" "ACS-rds" {
  name       = "acs-rds"
  subnet_ids = [var.private_subnets[0], var.private_subnets[1]]

  tags = merge(
    var.tags,
    {
      Name = "ACS-rds"
    },
  )
}

# RDS MySQL instance
resource "aws_db_instance" "ACS-rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "acsdb"
  username               = var.master_username
  password               = var.master_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.ACS-rds.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.datalayer_sg]
  multi_az               = true
}