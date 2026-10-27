variable "region" {
  type    = string
  default = "us-west-1"
}

variable "aurora_engine_version" {
  type        = string
  description = "Aurora MySQL version. 3.08+ is required for Serverless v2 scale-to-zero."
  default     = "8.0.mysql_aurora.3.10.6"
}
