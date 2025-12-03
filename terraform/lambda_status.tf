############################################################
# Package + deploy status Lambdas
# - archive_file data sources zip the Python handlers
# - Lambda functions wire in IAM roles and environment
############################################################

# Package the core uptime/summary Lambda
data "archive_file" "status_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/status_handler.py"
  output_path = "${path.module}/../lambda/status_handler.zip"
}

# Core status Lambda: returns uptime/alarm summary
resource "aws_lambda_function" "status" {
  function_name = "chris-nelson-dev-status"

  role    = aws_iam_role.status_lambda_role.arn
  handler = "status_handler.lambda_handler"
  runtime = "python3.12"

  filename         = data.archive_file.status_lambda_zip.output_path
  source_code_hash = data.archive_file.status_lambda_zip.output_base64sha256

  environment {
    variables = {
      ALARM_NAME = aws_cloudwatch_metric_alarm.site_health_alarm.alarm_name
    }
  }
}

# Package the detailed status API Lambda
data "archive_file" "status_api_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/status_api_handler.py"
  output_path = "${path.module}/../lambda/status_api_handler.zip"
}

# Detailed status API Lambda: latency + health-check endpoints
resource "aws_lambda_function" "status_api" {
  function_name = "chris-nelson-status-api"

  role    = aws_iam_role.status_api_lambda.arn
  handler = "status_api_handler.lambda_handler"
  runtime = "python3.11"

  filename         = data.archive_file.status_api_lambda_zip.output_path
  source_code_hash = data.archive_file.status_api_lambda_zip.output_base64sha256

  timeout = 10

  environment {
    variables = {
      ROUTE53_HEALTH_CHECK_ID  = aws_route53_health_check.site_https.id
      WAF_ENABLED              = var.enable_waf ? "true" : "false"
      WAF_BLOCK_COUNTRIES      = join(",", var.waf_block_countries)
      CF_DISTRIBUTION_ID       = aws_cloudfront_distribution.site.id
      WAF_WEB_ACL_METRIC_NAME  = var.create_waf ? aws_wafv2_web_acl.site[0].visibility_config[0].metric_name : ""
      WAF_REGION               = "Global"
      STATUS_API_FUNCTION_NAME = "chris-nelson-status-api"
    }
  }
}
