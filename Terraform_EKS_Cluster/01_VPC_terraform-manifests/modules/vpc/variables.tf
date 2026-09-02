variable "vpc_cidr" {
	description = "The CIDR block for the VPC"
	type        = string
}

variable "environment_name" {
	description = "Environment name to prefix resource names"
	type        = string
}

variable "subnet_newbits" {
	description = "Number of new bits to use when subnetting the VPC CIDR"
	type        = number
}

variable "tags" {
	description = "Map of tags to apply to resources"
	type        = map(string)
	default     = {}
}
