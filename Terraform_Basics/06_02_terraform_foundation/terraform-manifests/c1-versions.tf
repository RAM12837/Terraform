terraform {
    required_version = "~> 1.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.57.1"
        }
        random = {
            source  = "hashicorp/random"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}
