# Environment & Region 
environment_name = "dev1"
aws_region       = "us-east-1"

# CIDR for VPC
vpc_cidr = "10.1.0.0/16"

# Subnet mask (/24 subnets)
subnet_newbits = 8

# Tags 
tags = {
  Terraform   = "true"
  Project     = "retail-store"
  Owner       = "Kalyan Reddy Daida"
  Course = "DevOps Real-world Implementation Project on AWS Cloud"
  Demo = "terraform.tfvars demo"
}