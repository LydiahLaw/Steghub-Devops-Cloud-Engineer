variable "subnet_ids" {
  type = list(string)
}

variable "security_group" {
  type = string
}

variable "account_no" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}