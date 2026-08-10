# Environment & Region 
env_name = "dev2"
aws_region       = "us-east-1"

# CIDR for VPC
vpc_cidr = "10.2.0.0/16"

# Subnet mask (/24 subnets)
subnet_new_bites = 8

# Tags 
tags = {
  Terraform   = "true"
  Project     = "retail-store"
  Owner       = "Ram Kumar"
  Course = "DevOps Real-world Implementation Project on AWS Cloud"
  Demo = "dev.auto.tfvars demo"
}
