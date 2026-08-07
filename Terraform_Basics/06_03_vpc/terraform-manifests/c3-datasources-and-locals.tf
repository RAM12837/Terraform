# Datasource
data "aws_availability_zones" "available" {
  state = "available"
}

# Local Block
locals {
    azs = slice(data.aws_availability_zones.available.names, 0, 3)
    public_subnets = [for n, az in local.azs : cidrsubnet(var.vpc_cidr, var.subnet_new_bites, n)]
    private_subnets = [for n, az in local.azs : cidrsubnet(var.vpc_cidr, var.subnet_new_bites, n + 10)]
}
