resource "random_password" "aurora_master" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "aurora" {
  name       = "tooling-aurora"
  subnet_ids = local.eks.private_subnets
}

resource "aws_security_group" "aurora" {
  name        = "tooling-aurora"
  description = "MySQL access from inside the EKS VPC only"
  vpc_id      = local.eks.vpc_id

  ingress {
    description = "MySQL from the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.eks.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_rds_cluster" "tooling" {
  cluster_identifier     = "tooling-aurora"
  engine                 = "aurora-mysql"
  engine_mode            = "provisioned"
  engine_version         = var.aurora_engine_version
  master_username        = "admin"
  master_password        = random_password.aurora_master.result
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
  storage_encrypted      = true

  # Learning environment: easy teardown, no leftover snapshot costs
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  serverlessv2_scaling_configuration {
    min_capacity             = 0
    max_capacity             = 1
    seconds_until_auto_pause = 300
  }
}

resource "aws_rds_cluster_instance" "tooling" {
  identifier          = "tooling-aurora-1"
  cluster_identifier  = aws_rds_cluster.tooling.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.tooling.engine
  engine_version      = aws_rds_cluster.tooling.engine_version
  publicly_accessible = false
}
