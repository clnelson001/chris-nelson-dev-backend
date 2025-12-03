############################################################
# Site certificate (us-east-1) for CloudFront
# - Issues a certificate for apex + www in the region required
#   by CloudFront, then validates it via Route 53 DNS records.
############################################################

resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1
  domain_name       = var.root_domain
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.root_domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Certificate for ${var.root_domain}"
  }
}

############################################################
# DNS validation records for the site certificate
############################################################

resource "aws_route53_record" "site_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

############################################################
# Complete certificate validation
############################################################

resource "aws_acm_certificate_validation" "site" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.site.arn
  validation_record_fqdns = [
    for record in aws_route53_record.site_cert_validation : record.fqdn
  ]
}
