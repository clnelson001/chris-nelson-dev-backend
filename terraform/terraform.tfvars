# Vars for chris-nelson.dev back end
root_domain         = "chris-nelson.dev"
site_bucket_name    = "chris-nelson-dev-site-tf"
aws_region          = "us-east-1"
github_iam_username = "github-actions-site-deploy"
#site_alarm_email    = TF_VAR_site_alarm_email
#github_token        = TF_VAR_github_token

# Restrict to local access only?
#allowed_ip          = TF_VAR_allowed_ip
#enable_ip_lock = true
enable_ip_lock = false

# Toggle WAF geo-blocking for demo purposes
create_waf          = false
enable_waf          = false
waf_block_countries = ["SG", "AU"]
# WAF Country Codes ##############
# US health checkers
# US – United States

# EU health checkers
# IE – Ireland
# DE – Germany
# NL – Netherlands

# Asia Pacific health checkers
# JP – Japan
# SG – Singapore
# HK – Hong Kong
# AU – Australia

# South America health checkers
# BR – Brazil
