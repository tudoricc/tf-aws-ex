#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "environment" {}
# Configure the AWS Provider
provider "aws" {
  region = var.region_aws
}
data "aws_availability_zones" "available" {}
# we created the vpc in another tf module so we can use the data from the remote state here rather than hardcoding it
data "terraform_remote_state" "vpc" {
  backend = "local"

 config = {
    path = "${path.module}/../vpc/terraform.tfstate"
  }
}
#in case we want to associate it to the alb created previously
data "terraform_remote_state" "alb" {
  backend = "local"

 config = {
    path = "${path.module}/../alb/terraform.tfstate"
  }
}
data "terraform_remote_state" "iam-ecs-asg" {
  backend = "local"

 config = {
    path = "${path.module}/../iam-ecs-asg/terraform.tfstate"
  }
}
#module variables
locals {
  #Because we don't want this hardcoded we are retrieving hte VPC id from the remote state of the vpc module
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  #azs  = data.terraform_remote_state.vpc.outputs.az-available
  #We are retrieving the private db subnnets id from the remote state of the vpc moodule
  db_subnets = data.terraform_remote_state.vpc.outputs.db_subnets_ids
  

  #iam role

  aurora-cluster-name = "sonar-aurora-${var.region_aws}-${var.environment}"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}


################################################################################
# RDS Aurora Module
################################################################################
resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
#because I am cheap and I don't want extra costs  using servlerless so if it's not used we don't pay
module "aurora_postgresql" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = "${local.aurora-cluster-name}-postgresql"
  engine            = "aurora-postgresql"
  engine_mode       = "serverless"
  storage_encrypted = true
  master_username   = "root"

  vpc_id               = local.vpc_id
  db_subnet_group_name = local.db_subnets
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  manage_master_user_password = false
  master_password             = random_password.master.result

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  # enabled_cloudwatch_logs_exports = # NOT SUPPORTED

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 16
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }


}

