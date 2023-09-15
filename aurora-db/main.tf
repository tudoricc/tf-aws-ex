#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "environment" {}
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

  #We are retrieving the private db subnnets id from the remote state of the vpc moodule
  db_subnets = data.terraform_remote_state.vpc.outputs.db_subnets_ids
  

  #iam role

  aurora-cluster-name = "sonar-aurora-${var.region_aws}-${var.environment}"
}


################################################################################
# RDS Aurora Module
################################################################################

module "aurora" {
  source = "../../"

  name            = local.aurora-cluster-name
  engine          = "aurora-postgresql"
  engine_version  = "14.5"
  instance_class  = "db.serverless"
  instances       = { 1 = {} }
  master_username = "root"

  vpc_id               = local.vpc_id
  db_subnet_group_name = local.db_subnets
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  monitoring_interval           = 60
  iam_role_name                 = "${local.aurora-cluster-name}-monitor"
  iam_role_use_name_prefix      = true
  iam_role_description          = "${local.aurora-cluster-name} RDS enhanced monitoring IAM role"
  iam_role_path                 = "/autoscaling/"
  iam_role_max_session_duration = 7200

  apply_immediately   = true
  skip_final_snapshot = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.tags
}

module "disabled_aurora" {
  source = "../../"

  create = false
}