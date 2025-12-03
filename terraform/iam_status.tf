############################################################
# IAM roles/policies for status Lambdas
# - One role/policy for the uptime summary Lambda
# - One role with managed policies for the detailed status API
############################################################

# Role for the core status Lambda
resource "aws_iam_role" "status_lambda_role" {
  name = "chris-nelson-dev-status-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Inline policy: read CloudWatch alarms + write logs
resource "aws_iam_role_policy" "status_lambda_policy" {
  name = "chris-nelson-dev-status-lambda-policy"
  role = aws_iam_role.status_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["cloudwatch:DescribeAlarms"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Role for the detailed status API Lambda
resource "aws_iam_role" "status_api_lambda" {
  name = "status-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach managed policies (logs + Route53 read)
resource "aws_iam_role_policy_attachment" "status_api_lambda_basic_logs" {
  role       = aws_iam_role.status_api_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "status_api_lambda_route53" {
  role       = aws_iam_role.status_api_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53ReadOnlyAccess"
}

# Inline policy: read CloudWatch metrics for CloudFront/WAF/Lambda
resource "aws_iam_role_policy" "status_api_lambda_cloudwatch" {
  name = "status-api-lambda-cloudwatch-read"
  role = aws_iam_role.status_api_lambda.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ],
        Resource = "*"
      }
    ]
  })
}
