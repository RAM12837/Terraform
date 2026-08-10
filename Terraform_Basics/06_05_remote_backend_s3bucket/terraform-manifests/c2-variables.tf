variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "aws region to deploy the resources"
}

variable "tags" {
  type        = map(string)
  description = "Tag to deploy the resources"
  default = {
    terraform = "true"
  }
}


