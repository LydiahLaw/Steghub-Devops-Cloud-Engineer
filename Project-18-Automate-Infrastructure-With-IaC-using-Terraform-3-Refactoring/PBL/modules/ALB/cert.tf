# =============================================================================
# ACM CERTIFICATE — COMMENTED OUT (no domain available)
# =============================================================================
# To enable this in future:
# 1. Register a domain
# 2. Create a hosted zone in Route 53
# 3. Uncomment this block and replace "yourdomain.com" with your actual domain
# =============================================================================

# resource "aws_acm_certificate" "cert" {
#   domain_name       = "*.yourdomain.com"
#   validation_method = "DNS"
# }

# data "aws_route53_zone" "hostedzone" {
#   name         = "yourdomain.com"
#   private_zone = false
# }

# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.hostedzone.zone_id
# }

# resource "aws_acm_certificate_validation" "cert" {
#   certificate_arn         = aws_acm_certificate.cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }

# resource "aws_route53_record" "tooling" {
#   zone_id = data.aws_route53_zone.hostedzone.zone_id
#   name    = "tooling.yourdomain.com"
#   type    = "A"
#   alias {
#     name                   = aws_lb.ext-alb.dns_name
#     zone_id                = aws_lb.ext-alb.zone_id
#     evaluate_target_health = true
#   }
# }

# resource "aws_route53_record" "wordpress" {
#   zone_id = data.aws_route53_zone.hostedzone.zone_id
#   name    = "wordpress.yourdomain.com"
#   type    = "A"
#   alias {
#     name                   = aws_lb.ext-alb.dns_name
#     zone_id                = aws_lb.ext-alb.zone_id
#     evaluate_target_health = true
#   }
# }
