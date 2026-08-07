# 1. Aws Region 
variable "aws_region" {
    description = "Aws region to deploy the resources"
    type = string
    default = "us-east-1"
}

# 2. Environment Name 
variable "env_name" {
    description = "Environment name to deploy the resources"
    type = string
    default = "dev"
}
# 3. VPC CIDR
variable "vpc_cidr" {
    description = "Vpc CIDR block to deploy the resources"
    type = string
    default = "10.0.0.0/16"
}
# 4. Tag
variable "tag" {
    description = "Tag to deploy the resources"
    type = map(string)
    default = {
        terraform = "true"
    }
}
# 5. subnet new bits
variable "subnet_new_bites" {
    description = "Subnet new bits to deploy the resources"
    type = number
    default = 8
}
