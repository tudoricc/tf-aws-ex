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
  public_subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  default_sg_id = data.terraform_remote_state.vpc.outputs.default_sg_id
}
resource "aws_security_group" "lb" {
  name        = "example-alb-security-group"
  vpc_id      = local.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 3000
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "sonar-${var.region_aws}-${var.environment}"

  load_balancer_type = "application"

  vpc_id             = local.vpc_id
  subnets            = local.public_subnets
  security_groups    = [ aws_security_group.lb.id]
}
#create the target group - for now we'll assume it's gonna be used by ecs
resource "aws_lb_target_group" "ecs" {
  name     = "ecs"
  #modifying the targetrgoup here means that you will need to destroy the LB and hten recreate it
  port     = 3000
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 300
    path                = "/"
    timeout             = 60
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = module.alb.lb_arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}


output "alb_name" {
  value = module.alb.lb_dns_name
}
output "alb_arn" {
  value = module.alb.lb_id
}
output "ecs_target_group" {
  value = aws_lb_target_group.ecs.arn
} 

output "alb_sg_id" {
  value = aws_security_group.lb.id
}