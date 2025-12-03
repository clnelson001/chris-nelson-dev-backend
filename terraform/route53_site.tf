############################################################
# Public DNS records for the website
# - Apex and www aliases pointing to CloudFront
############################################################

resource "aws_route53_record" "site_a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.root_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_site_a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
