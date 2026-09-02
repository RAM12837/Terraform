module "vpc" {
    source = "./modules/vpc"
    vpc_cidr        = var.vpc_cidr
    environment_name = var.environment_name
    subnet_newbits  = var.subnet_newbits
    tags            = var.tags
}