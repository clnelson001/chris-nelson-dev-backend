############################################################
# Input variables
# - Core settings for AWS region, domains, WAF, alarms, etc.
############################################################

variable "aws_region" {
  description = "AWS region for S3, Route53, IAM, etc."
  type        = string
  default     = "us-east-1"
}

variable "site_bucket_name" {
  description = "S3 bucket name for the static site (must be globally unique)"
  type        = string
  default     = "chris-nelson-dev-site-tf"
}

variable "root_domain" {
  description = "Root domain name (e.g., chris-nelson.dev)"
  type        = string
}

variable "github_iam_username" {
  description = "IAM username for GitHub Actions deployments"
  type        = string
  default     = "github-actions-site-deploy"
}

variable "allowed_ip" {
  description = "Public IP address allowed to access CloudFront"
  type        = string
}

variable "enable_ip_lock" {
  description = "Enable CloudFront IP restriction function"
  type        = bool
  default     = true
}

variable "site_alarm_email" {
  description = "Email address for uptime and error alerts"
  type        = string
}

variable "route53_health_check_id" {
  description = "Route 53 health check ID for chris-nelson.dev used by the status API"
  type        = string
  default     = ""

}
variable "create_waf" {
  type        = bool
  description = "Whether to create the WAF Web ACL resource"
  default     = false
}

variable "enable_waf" {
  type        = bool
  description = "Whether to attach the WAF Web ACL to CloudFront"
  default     = false
}

variable "waf_block_countries" {
  type        = list(string)
  description = "List of ISO country codes to block with WAF GeoMatch"
  default     = []
}

