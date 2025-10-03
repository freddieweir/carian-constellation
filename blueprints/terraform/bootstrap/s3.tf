# S3 Buckets for Terraform State and Backups

# ============================================================================
# Terraform State Bucket
# ============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.project_prefix}-tfstate-${local.unique_suffix}"
  
  tags = merge(local.common_tags, {
    Name        = "Terraform State Storage"
    Service     = "terraform"
    Component   = "state-backend"
    Purpose     = "terraform-state"
    Critical    = "true"
    DataType    = "infrastructure-state"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = var.terraform_state_retention_days
    }
  }
}

# ============================================================================
# Backup Bucket
# ============================================================================

resource "aws_s3_bucket" "backups" {
  bucket = "${local.project_prefix}-backups-${local.unique_suffix}"
  
  tags = merge(local.common_tags, {
    Name        = "Constellation Data Backups"
    Service     = "storage"
    Component   = "backups"
    Purpose     = "data-backups"
    Critical    = "true"
    DataType    = "application-data"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    
    expiration {
      days = var.backup_retention_days
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
  
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    
    transition {
      days          = 7
      storage_class = "GLACIER_IR"
    }
  }
}

# ============================================================================
# DynamoDB Table for State Locking
# ============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${local.project_prefix}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = merge(local.common_tags, {
    Name      = "Terraform State Lock"
    Service   = "terraform"
    Component = "state-locking"
    Purpose   = "terraform-lock"
    Critical  = "true"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}
