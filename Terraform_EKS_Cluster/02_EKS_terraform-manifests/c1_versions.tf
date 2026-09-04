terraform {
  required_version = ">= 0.12"
  aws {
    source  = "hashicorp/aws"
    version = "~> 4.0"
  }

  backend "s3" {
    bucket = "mybucket-dbstl"
    key = "vpc/dev/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
