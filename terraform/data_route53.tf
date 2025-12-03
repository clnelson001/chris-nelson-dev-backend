############################################################
# Shared DNS context
# - Looks up the public hosted zone for the root domain so
#   all DNS and ACM validation records reference a single
#   data source instead of redefining it in multiple files.
############################################################

data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
}
