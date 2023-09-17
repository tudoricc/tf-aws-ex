#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "compute_subnets" {}
variable "db_subnets" {}
variable "azs" {}
variable "environment" {}
variable "public_subnets" {}
# Configure the AWS Provider
provider "aws" {
  region = var.region_aws
}
#module variables
locals {
  #create a list with all the private subnets defined for db and compute
  private_subnets = concat(var.compute_subnets,var.db_subnets)
  #create a "huuman friendly VPC name"
  vpc_name = "sonar-vpc-${var.region_aws}-${var.environment}"
}
#VPC subnet calculator: https://www.davidc.net/sites/default/subnets/subnets.html
#if you want you can create everything from scratch but why not use an already existing module
module "vpc" {
  #name of the pre-made module
  source = "terraform-aws-modules/vpc/aws"

  name = local.vpc_name
  cidr = "10.0.0.0/16"

  azs             = var.azs
  private_subnets = var.compute_subnets
  database_subnets = var.db_subnets
  public_subnets  = var.public_subnets
  single_nat_gateway = false
  one_nat_gateway_per_az = true
  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


#Outputs,these will be also used for retrieving VPC ID for creating resources in the right VPC and right subnet
output "az-available" {
  value = var.azs
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
output "default_sg_id"{
  value = module.vpc.default_security_group_id
}
output "compute_subnets_ids" {
  value = module.vpc.private_subnets
}

output "db_subnets_ids" {
  value = module.vpc.database_subnet_group_name
}

output "public_subnets"{
  value = module.vpc.public_subnets
}