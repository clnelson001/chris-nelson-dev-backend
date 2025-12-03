############################################################
# IAM for GitHub Actions deploy user
# - User + inline policy for S3 sync and CF invalidation
# - Access key exported as GitHub Actions secret
############################################################

resource "aws_iam_user" "github_actions" {
  name          = var.github_iam_username
  force_destroy = true
  tags = {
    Name = "GitHub Actions deploy user for ${var.root_domain}"
  }
}

# Policy: allow this user to sync to the site bucket + invalidate CloudFront
resource "aws_iam_user_policy" "github_actions_policy" {
  name = "github-actions-deploy-policy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Deploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.site.arn,
          "${aws_s3_bucket.site.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidate"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.site.arn
      }
    ]
  })
}

# Access key for GitHub Actions (will be used as secrets in GitHub)
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}
