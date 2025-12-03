############################################################
# Outputs for deployment + integrations
############################################################

output "site_bucket_name" {
  description = "S3 bucket name for the site"
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (use for AWS_DISTRIBUTION_ID secret)"
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "route53_zone_id" {
  description = "Hosted zone ID for the root domain"
  value       = data.aws_route53_zone.main.zone_id
}

output "github_aws_access_key_id" {
  description = "Access key ID for GitHub Actions IAM user"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_aws_secret_access_key" {
  description = "Secret access key for GitHub Actions IAM user"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "github_actions_access_key_id" {
  description = "Access key ID for GitHub Actions IAM user (duplicate for compatibility)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret access key for GitHub Actions IAM user (duplicate for compatibility)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}
