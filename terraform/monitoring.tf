############################################################
# Monitoring + alerts
# - Route 53 health check
# - SNS topic/subscription
# - CloudWatch alarm on health check
############################################################

resource "aws_route53_health_check" "site_https" {
  fqdn              = var.root_domain
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3

  enable_sni      = true
  measure_latency = true

  tags = {
    Name = "chris-nelson-dev-https-healthcheck"
  }
}

resource "aws_sns_topic" "site_alarms" {
  name = "chris-nelson-dev-alarms"
}

resource "aws_sns_topic_subscription" "site_alarms_email" {
  topic_arn = aws_sns_topic.site_alarms.arn
  protocol  = "email"
  endpoint  = var.site_alarm_email
}

resource "aws_cloudwatch_metric_alarm" "site_health_alarm" {
  alarm_name          = "chris-nelson-dev-uptime"
  alarm_description   = "Alerts when Route 53 health check for chris-nelson.dev is unhealthy"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = 1

  dimensions = {
    HealthCheckId = aws_route53_health_check.site_https.id
  }

  alarm_actions = [
    aws_sns_topic.site_alarms.arn
  ]

  ok_actions = [
    aws_sns_topic.site_alarms.arn
  ]
}
