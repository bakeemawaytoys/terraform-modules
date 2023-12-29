output "arn" {
  description = "The ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket" {
  description = "The name of the bucket.  An alias of the `name` and `id` outputs."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_domain_name" {
  description = "Bucket domain name. Will be of format bucketname.s3.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Bucket region-specific domain name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "The Route53 hosted zone ID for the bucket's region."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "id" {
  description = "The name of the bucket. An alias of the `name` and `bucket` outputs."
  value       = aws_s3_bucket.this.id
}

output "name" {
  description = "The name of the bucket. An alias of the `bucket` and `id` outputs."
  value       = aws_s3_bucket.this.bucket
}

output "region" {
  description = "The AWS region in which the bucket resides."
  value       = aws_s3_bucket.this.region
}
