output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "database_endpoint" {
  description = "PostgreSQL database endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "cache_endpoint" {
  description = "Redis cache endpoint"
  value       = module.redis.endpoint
  sensitive   = true
}

output "audit_bucket" {
  description = "S3 bucket for audit logs with WORM"
  value       = module.s3_worm.bucket_name
}

output "sns_events_topic" {
  description = "SNS topic for DCR events"
  value       = module.messaging.sns_topic_arn
}

output "sqs_audit_queue" {
  description = "SQS queue for audit processing"
  value       = module.messaging.sqs_queue_urls["audit"]
}

output "region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
