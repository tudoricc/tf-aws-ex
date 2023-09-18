#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "environment" {}
variable "azs" {
  type = list
}
# Configure the AWS Provider
provider "aws" {
  region = var.region_aws
}

# we created the vpc in another tf module so we can use the data from the remote state here rather than hardcoding it
data "terraform_remote_state" "vpc" {
  backend = "local"

 config = {
    path = "${path.module}/../vpc/terraform.tfstate"
  }
}
#module variables
locals {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  compute_subnets = data.terraform_remote_state.vpc.outputs.compute_subnets_ids
  securitygroup_id = data.terraform_remote_state.vpc.outputs.default_sg_id
}


#Using the public aws ec2 TF module with the right parameters
#Docs: https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest
#Looping through each of the subnets and then creating a resource in each AZ/compute subnet
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  
  for_each             =  { for subnet_id_compute in local.compute_subnets:  index(local.compute_subnets, subnet_id_compute) => subnet_id_compute }

  name = "sonar-${var.azs[each.key]}-${var.environment}"

  instance_type          = "t2.micro"

  monitoring             = true
  #the module wants a list so we use tolist
  vpc_security_group_ids = [local.securitygroup_id]
  subnet_id              = each.value

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#Let's output each of the EC2 instances
output "ec2_instance_id" {

  value = tolist(module.ec2_instance[*])
}