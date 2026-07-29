# Resouruce Block: Random String
resource "random_string" "suffix" {
  length = 6
  special = false
  upper = false
}

# Resource Block: AWS S3 Bucket
resource "aws_s3_bucket" "demo_bucket" {
  bucket = "devopsdemo-${random_string.suffix.result}"

  tags = {
    Name        = "DevOps Demo Bucket"
    Environment = "Dev"
    # Owner = "Kalyan Reddy"
    # Organization = "StackSimplify"
  }
}





