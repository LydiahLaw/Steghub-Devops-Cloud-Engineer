variable "cert_manager_namespace" {
  description = "Namespace cert-manager is installed into"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.15.3"
}

variable "hosted_zone_arn" {
  description = "ARN of the Route 53 hosted zone for lydiahnganga.cloud"
  type        = string
}

variable "acme_email" {
  description = "Email address for Let's Encrypt registration/expiry notices"
  type        = string
}

variable "domain" {
  description = "Fully-qualified domain name for the Artifactory Ingress"
  type        = string
  default     = "tooling.artifactory.lydiahnganga.cloud"
}

variable "route53_dns01_region" {
  description = "AWS region used for signing Route53 API calls in the DNS-01 solver"
  type        = string
  default     = "us-east-1"
}
