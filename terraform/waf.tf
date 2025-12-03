# WAFv2 Web ACL for CloudFront.
# Controlled by:
#
#   create_waf = true  -> ACL exists
#   create_waf = false -> ACL is not created (zero WAF cost)
#
# Attachment is controlled separately by enable_waf in cloudfront.tf

resource "aws_wafv2_web_acl" "site" {
  count    = var.create_waf ? 1 : 0
  provider = aws.us_east_1

  name        = "chris-nelson-dev-waf"
  scope       = "CLOUDFRONT"
  description = "WAF for chris-nelson.dev CloudFront distribution"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "chris-nelson-dev-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "GeoBlockDemo"
    priority = 10

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = var.waf_block_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "chris-nelson-dev-waf-geo"
      sampled_requests_enabled   = true
    }
  }
}
