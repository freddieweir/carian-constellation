# IAM Security Configuration

# ============================================================================
# MFA Enforcement Policy
# ============================================================================

resource "aws_iam_policy" "require_mfa" {
  name        = "${local.project_prefix}-require-mfa"
  description = "Require MFA for all AWS actions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name      = "MFA Enforcement Policy"
    Service   = "security"
    Component = "iam"
    Purpose   = "mfa-enforcement"
    Critical  = "true"
  })
}

# ============================================================================
# Constellation Admin User (Optional - for dedicated IAM user)
# ============================================================================

# Uncomment this if you want a dedicated IAM user for Constellation
# Otherwise, use your existing AWS user with MFA

# resource "aws_iam_user" "constellation_admin" {
#   name = "${local.project_prefix}-admin"
#   path = "/constellation/"
#   
#   tags = merge(local.common_tags, {
#     Name    = "Constellation Administrator"
#     Service = "iam"
#     Role    = "administrator"
#   })
# }

# resource "aws_iam_user_policy_attachment" "constellation_admin_mfa" {
#   user       = aws_iam_user.constellation_admin.name
#   policy_arn = aws_iam_policy.require_mfa.arn
# }

# resource "aws_iam_user_policy_attachment" "constellation_admin_access" {
#   user       = aws_iam_user.constellation_admin.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

# ============================================================================
# Service Role for Automated Operations (Future)
# ============================================================================

# This role can be assumed by CI/CD or automation tools
# Currently not used, but ready for future automation

resource "aws_iam_role" "automation" {
  name               = "${local.project_prefix}-automation"
  description        = "Role for automated constellation operations"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${local.project_prefix}-automation"
          }
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name      = "Automation Role"
    Service   = "iam"
    Component = "automation"
    Purpose   = "ci-cd"
  })
}

resource "aws_iam_role_policy_attachment" "automation_admin" {
  role       = aws_iam_role.automation.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
