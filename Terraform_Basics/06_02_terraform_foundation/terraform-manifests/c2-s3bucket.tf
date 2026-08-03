# Resouruce Block: Random String
resource "random_string" "suffix" {
  length = 4
  special = false
  upper = false
}

# Resource Block: AWS S3 Bucket
resource "aws_s3_bucket" "demo_bucket" {
    bucket = "terraform-demo-${random_string.suffix.result}" # Must be global unique
    tags = {
        name = "Devops-terraform-demo"
        Environment = "Dev"
    }
}