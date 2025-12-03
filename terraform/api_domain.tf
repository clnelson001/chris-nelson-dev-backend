############################################################
# API custom domain (api.chris-nelson.dev)
# - Issues us-east-1 cert (required by API Gateway)
# - Maps custom domain to the status API stage
############################################################

resource "aws_acm_certificate" "api_cert" {
  provider          = aws.us_east_1
  domain_name       = "api.chris-nelson.dev"
  validation_method = "DNS"

  tags = {
    Name = "api.chris-nelson.dev API certificate"
  }
}

#########################################################
# DNS validation records for the api.chris-nelson.dev cert
#########################################################

resource "aws_route53_record" "api_cert_validation" {
  zone_id = data.aws_route53_zone.main.zone_id

  # Create one DNS record per validation option
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "api_cert_validation_complete" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.api_cert.arn

  validation_record_fqdns = [
    for record in aws_route53_record.api_cert_validation :
    record.fqdn
  ]
}

#########################################################
# API Gateway custom domain: api.chris-nelson.dev
#########################################################

resource "aws_apigatewayv2_domain_name" "api_domain" {
  domain_name = "api.chris-nelson.dev"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api_cert_validation_complete.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

#########################################################
# Route 53 alias record to the API Gateway domain
#########################################################

resource "aws_route53_record" "api_domain_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = aws_apigatewayv2_domain_name.api_domain.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

#########################################################
# Map the custom domain to your existing status API
#########################################################

resource "aws_apigatewayv2_api_mapping" "status_mapping" {
  api_id      = aws_apigatewayv2_api.status_api.id
  domain_name = aws_apigatewayv2_domain_name.api_domain.domain_name
  stage       = aws_apigatewayv2_stage.status_stage.name
}

#########################################################
# Stable API base URL output
#########################################################

output "api_base_url" {
  description = "Stable base URL for status API via custom domain"
  value       = "https://api.chris-nelson.dev"
}
