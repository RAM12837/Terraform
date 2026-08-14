data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 0),
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 1),
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 2)
  ]
  public_subnets = [
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 10),
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 11),
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, 12)
  ]
}
