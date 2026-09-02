variable "aws_region" {
    default     = "us-east-1"
    description = "Aws region to deploy the resources"
    type = string
}

variable "environment_name" {
    default = "dev"
    description = "Environment name to deploy the resource"
    type = string
}

variable "tags" {
    default = {
        terraform = true
    }
    description = "Global tag to deploy all resources"
    type = map(string)
}

variable "vpc_cidr" {
    description = "cidr block for the vpc"
    type = string
    default = "10.0.0.0/16"
}

variable "subnet_newbits" {
    description = "Number of new bits to add to VPC CIDR to generate subnets (e.g., 8 means /24 from /16)"
    type = number
    default = 8
}
