############################################################
# CloudFront distribution for the static site
# - Protects S3 with OAC
# - Optionally attaches WAF and IP restriction function
############################################################

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-${var.root_domain}"
  description                       = "OAC for ${var.root_domain} S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Optional IP restriction function (viewer-request)
resource "aws_cloudfront_function" "ip_restrict" {
  name    = "cf-ip-restrict"
  runtime = "cloudfront-js-1.0"

  code = <<EOF
function handler(event) {
  var request = event.request;
  var ip = event.viewer.ip;

  var allowedIp = "${var.allowed_ip}";

  if (ip === allowedIp) {
    return request;
  }

  return {
    statusCode: 403,
    statusDescription: "Forbidden",
    headers: {
      "content-type": { value: "text/plain" }
    },
    body: "Access denied"
  };
}
EOF
}

resource "aws_cloudfront_distribution" "site" {
  depends_on = [aws_acm_certificate_validation.site]

  web_acl_id = var.create_waf && var.enable_waf ? aws_wafv2_web_acl.site[0].arn : null

  enabled             = true
  comment             = "CloudFront distribution for ${var.root_domain}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [
    var.root_domain,
    "www.${var.root_domain}"
  ]

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-${aws_s3_bucket.site.bucket}"

    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.bucket}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    dynamic "function_association" {
      for_each = var.enable_ip_lock ? [1] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.ip_restrict.arn
      }
    }

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "CloudFront for ${var.root_domain}"
  }
}
