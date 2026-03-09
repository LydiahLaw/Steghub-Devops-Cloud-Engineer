variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "ALB_sg" {
  type = string
}

variable "internal_alb_sg" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
