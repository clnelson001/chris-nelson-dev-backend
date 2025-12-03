############################################################
# GitHub provider + Actions secrets
# - Provider uses PAT (classic) supplied via github_token variable
# - Secrets expose AWS credentials + CloudFront distribution ID
############################################################

provider "github" {
  token = var.github_token
  owner = "clnelson001"
}

variable "github_token" {
  type        = string
  description = "GitHub personal access token for managing Actions secrets"
  sensitive   = true
}

# GitHub Actions secret for AWS access key id
resource "github_actions_secret" "aws_access_key_id" {
  repository      = "chris-nelson-dev"
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.github_actions.id
}

# GitHub Actions secret for AWS secret access key
resource "github_actions_secret" "aws_secret_access_key" {
  repository      = "chris-nelson-dev"
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.github_actions.secret
}

# GitHub Actions secret for CloudFront distribution id
resource "github_actions_secret" "cloudfront_distribution_id" {
  repository      = "chris-nelson-dev"
  secret_name     = "AWS_DISTRIBUTION_ID"
  plaintext_value = aws_cloudfront_distribution.site.id
}
