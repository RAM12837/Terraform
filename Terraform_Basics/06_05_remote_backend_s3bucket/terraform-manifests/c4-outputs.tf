output "bucket_name" {
  value       = aws_s3_bucket.my_bucket.id
  description = "Name of the S3 bucket"
}

output "bucket_arn" {
  value       = aws_s3_bucket.my_bucket.arn
  description = "ARN of the S3 bucket"
}
