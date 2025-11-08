terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "dcr-terraform-state"
    key            = "dcr-enterprise/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "DCR Enterprise"
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "OpenFinance"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets
  enable_nat_gateway  = true
  single_nat_gateway  = var.environment == "dev" ? true : false
  enable_dns_hostnames = true
  
  tags = var.tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  environment        = var.environment
  cluster_name       = "dcr-${var.environment}"
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    dcr_services = {
      desired_size   = var.eks_node_desired_size
      min_size       = var.eks_node_min_size
      max_size       = var.eks_node_max_size
      instance_types = var.eks_node_instance_types
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      
      labels = {
        workload = "dcr-service"
      }
      
      taints = []
    }
  }
  
  tags = var.tags
}

# RDS PostgreSQL Module
module "rds" {
  source = "./modules/rds"
  
  environment            = var.environment
  identifier             = "dcr-registry-${var.environment}"
  engine_version         = "14.10"
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  max_allocated_storage  = var.rds_max_allocated_storage
  
  db_name  = "dcr_registry"
  username = "dcr_admin"
  
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids
  allowed_security_groups = [module.eks.worker_security_group_id]
  
  backup_retention_period = var.rds_backup_retention_days
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  multi_az               = var.environment == "prd" ? true : false
  deletion_protection    = var.environment == "prd" ? true : false
  
  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  
  tags = var.tags
}

# ElastiCache Redis Module
module "redis" {
  source = "./modules/redis"
  
  environment         = var.environment
  cluster_id          = "dcr-cache-${var.environment}"
  engine_version      = "7.0"
  node_type           = var.redis_node_type
  num_cache_nodes     = var.redis_num_nodes
  
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_security_groups = [module.eks.worker_security_group_id]
  
  parameter_group_family = "redis7"
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]
  
  snapshot_retention_limit = var.redis_snapshot_retention_days
  snapshot_window         = "03:00-05:00"
  
  automatic_failover_enabled = var.environment == "prd" ? true : false
  multi_az_enabled          = var.environment == "prd" ? true : false
  
  tags = var.tags
}

# S3 WORM Bucket Module
module "s3_worm" {
  source = "./modules/s3-worm"
  
  environment = var.environment
  bucket_name = "dcr-audit-worm-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  object_lock_enabled = true
  object_lock_mode    = "COMPLIANCE"
  object_lock_days    = var.audit_retention_days
  
  versioning_enabled = true
  
  lifecycle_rules = [
    {
      id      = "transition-to-glacier"
      enabled = true
      
      transitions = [
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
    }
  ]
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.kms.key_id
      }
    }
  }
  
  tags = var.tags
}

# SNS/SQS Module
module "messaging" {
  source = "./modules/sns-sqs"
  
  environment = var.environment
  
  sns_topic_name = "dcr-events-${var.environment}"
  
  sqs_queues = {
    audit = {
      name                       = "dcr-audit-${var.environment}"
      visibility_timeout_seconds = 300
      message_retention_seconds  = 1209600  # 14 days
      max_message_size           = 262144   # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20       # Long polling
      
      redrive_policy = {
        deadLetterTargetArn = module.messaging.dlq_arn
        maxReceiveCount     = 3
      }
    }
  }
  
  enable_encryption = true
  kms_key_id        = module.kms.key_id
  
  tags = var.tags
}

# KMS Module
module "kms" {
  source = "./modules/kms"
  
  environment = var.environment
  description = "DCR Enterprise encryption key"
  
  deletion_window_in_days = var.environment == "prd" ? 30 : 7
  enable_key_rotation     = true
  
  aliases = ["alias/dcr-${var.environment}"]
  
  tags = var.tags
}

# IAM Roles for Service Accounts (IRSA)
module "irsa" {
  source = "./modules/irsa"
  
  environment          = var.environment
  cluster_name         = module.eks.cluster_name
  oidc_provider_arn    = module.eks.oidc_provider_arn
  
  service_accounts = {
    dcr_service = {
      namespace        = "openfinance"
      service_account  = "dcr-service"
      
      policy_arns = []
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:PutObject",
              "s3:PutObjectRetention",
              "s3:PutObjectLegalHold"
            ]
            Resource = "${module.s3_worm.bucket_arn}/*"
          },
          {
            Effect = "Allow"
            Action = [
              "sns:Publish"
            ]
            Resource = module.messaging.sns_topic_arn
          },
          {
            Effect = "Allow"
            Action = [
              "sqs:SendMessage",
              "sqs:GetQueueUrl"
            ]
            Resource = module.messaging.sqs_queue_arns["audit"]
          },
          {
            Effect = "Allow"
            Action = [
              "kms:Decrypt",
              "kms:GenerateDataKey"
            ]
            Resource = module.kms.key_arn
          }
        ]
      })
    }
  }
  
  tags = var.tags
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.endpoint
  sensitive   = true
}

output "s3_worm_bucket" {
  description = "S3 WORM bucket name"
  value       = module.s3_worm.bucket_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = module.messaging.sns_topic_arn
}

output "sqs_audit_queue_url" {
  description = "SQS audit queue URL"
  value       = module.messaging.sqs_queue_urls["audit"]
}

output "dcr_service_role_arn" {
  description = "IAM role ARN for DCR service"
  value       = module.irsa.role_arns["dcr_service"]
}
