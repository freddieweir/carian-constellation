# Route53 Configuration

# ============================================================================
# Hosted Zone
# ============================================================================

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Managed by Terraform for Carian Constellation"
  
  tags = merge(local.common_tags, {
    Name      = "${var.domain_name} - Constellation DNS"
    Service   = "networking"
    Component = "dns"
    Purpose   = "domain-management"
    Domain    = var.domain_name
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================================
# SOA Record (Start of Authority)
# ============================================================================

# SOA is automatically created by AWS, we just document it here
# You can view it with: aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# ============================================================================
# NS Record Outputs for Domain Registrar
# ============================================================================

# These nameservers need to be configured at your domain registrar
# Example:
# ns-123.awsdns-12.com
# ns-456.awsdns-34.net
# ns-789.awsdns-56.org
# ns-012.awsdns-78.co.uk
