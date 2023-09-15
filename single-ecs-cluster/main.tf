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
#module variables
locals {
  #Because we don't want this hardcoded we are retrieving hte VPC id from the remote state of the vpc module
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  #We are retrieving the private computer subnnets id from the remote state of the vpc moodule
  compute_subnets = data.terraform_remote_state.vpc.outputs.compute_subnets_ids
  #alb info
  alb_arn = data.terraform_remote_state.alb.outputs.alb_arn
  ecs_target_group = data.terraform_remote_state.alb.outputs.ecs_target_group
  alb_sg_id = data.terraform_remote_state.alb.outputs.alb_sg_id


}

#Simple Hello world app for now.
resource "aws_ecs_task_definition" "hello_world" {
  family                   = "hello-world-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048

  container_definitions = <<DEFINITION
[
  {
    "image": "registry.gitlab.com/architect-io/artifacts/nodejs-hello-world:latest",
    "cpu": 1024,
    "memory": 2048,
    "name": "hello-world-app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ]
  }
]
DEFINITION
}


#The SG that will put on the service that  will only accept traffic from the ALB(let's not open it to the internet)
resource "aws_security_group" "hello_world_task" {
  name        = "sonar-${var.region_aws}-${var.environment}-task-security-group"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [ local.alb_sg_id ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#create a cluster with nothing in it now
resource "aws_ecs_cluster" "main" {
  name = "sonar-${var.region_aws}-${var.environment}"
}

#create the service and associate it to the cluster you created before
resource "aws_ecs_service" "hello_world" {
  name            = "sonar-${var.region_aws}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hello_world.arn
  #if you change the desired_count to 2 it means that the tasks will be spread evenly across each subnet
  # in this case it's spreading it evenly across each subnet
  desired_count   = 3 #for the azs count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.hello_world_task.id]
    subnets         = local.compute_subnets
  }
   load_balancer {
    target_group_arn = local.ecs_target_group
    container_name = "hello-world-app"
    container_port = 3000
  }


  
}


output "ECS-CLUSTER-ARN" {
  value = aws_ecs_cluster.main.id
}