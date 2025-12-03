############################################################
# API Gateway v2 (HTTP) for status endpoints
# - Single API with two Lambdas behind proxy integrations
# - Routes for /status, /status/latency, /status/health-checkers
############################################################

# HTTP API + CORS for the frontend
resource "aws_apigatewayv2_api" "status_api" {
  name          = "chris-nelson-dev-status-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "https://chris-nelson.dev",
      "https://www.chris-nelson.dev"
    ]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
  }
}

# Integration: /status -> core status Lambda
resource "aws_apigatewayv2_integration" "status_integration" {
  api_id                 = aws_apigatewayv2_api.status_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.status.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Route: GET /status
resource "aws_apigatewayv2_route" "status_route" {
  api_id    = aws_apigatewayv2_api.status_api.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.status_integration.id}"
}

# Stage: prod with light throttling
resource "aws_apigatewayv2_stage" "status_stage" {
  api_id      = aws_apigatewayv2_api.status_api.id
  name        = "prod"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 0.5
  }
}

# Allow API Gateway to invoke the core status Lambda
resource "aws_lambda_permission" "status_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.status_api.execution_arn}/*/*"
}

############################################################
# Secondary Lambda integration: latency + health-check routes
############################################################

resource "aws_apigatewayv2_integration" "status_api_status_lambda" {
  api_id             = aws_apigatewayv2_api.status_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.status_api.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "status_latency_route" {
  api_id    = aws_apigatewayv2_api.status_api.id
  route_key = "GET /status/latency"
  target    = "integrations/${aws_apigatewayv2_integration.status_api_status_lambda.id}"
}

resource "aws_apigatewayv2_route" "status_health_route" {
  api_id    = aws_apigatewayv2_api.status_api.id
  route_key = "GET /status/health-checkers"
  target    = "integrations/${aws_apigatewayv2_integration.status_api_status_lambda.id}"
}

# Route: GET /status/metrics (CloudFront/WAF/Lambda metrics bundle)
resource "aws_apigatewayv2_route" "status_metrics_route" {
  api_id    = aws_apigatewayv2_api.status_api.id
  route_key = "GET /status/metrics"
  target    = "integrations/${aws_apigatewayv2_integration.status_api_status_lambda.id}"
}

resource "aws_lambda_permission" "status_api_allow_invoke" {
  statement_id  = "AllowAPIGatewayInvokeStatusApiNew"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.status_api.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.status_api.execution_arn}/*/*"
}

############################################################
# Outputs: handy URLs for consumers
############################################################

output "status_api_url" {
  description = "URL for uptime status API"
  value       = "${aws_apigatewayv2_api.status_api.api_endpoint}/${aws_apigatewayv2_stage.status_stage.name}/status"
}
