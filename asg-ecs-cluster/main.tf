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

  #We are retrieving the private computer subnnets id from the remote state of the vpc moodule along with other important vars
  compute_subnets = data.terraform_remote_state.vpc.outputs.compute_subnets_ids
  alb_arn = data.terraform_remote_state.alb.outputs.alb_arn
  ecs_target_group = data.terraform_remote_state.alb.outputs.ecs_target_group
  alb_sg_id = data.terraform_remote_state.alb.outputs.alb_sg_id

  #iam role
  iam-role =  data.terraform_remote_state.iam-ecs-asg.outputs.ecs-iam-role
}

#Simple Hello world app for now.
resource "aws_ecs_task_definition" "hello_world" {
  family                   = "hello-world-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn = local.iam-role
  task_role_arn = local.iam-role
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
  name        = "sonar-${var.region_aws}-${var.environment}-ASG-task-security-group"
  vpc_id      = local.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [local.alb_sg_id]
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
  name = "sonar-${var.region_aws}-${var.environment}-with-ASG"
}

#create the service and associate it to the cluster you created before
resource "aws_ecs_service" "hello_world" {
  name            = "sonar-${var.region_aws}-${var.environment}-service-ASG"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hello_world.arn
  #we create a task here right?
  desired_count   = 1 
  launch_type     = "FARGATE"
  lifecycle {
    ignore_changes = [
      desired_count]
  }
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

#So far we ccreated the clsuter again but we want to have it autoscaling for different metrics - I KNOW IT's a lot of duplicated code/can be cleaned up:
# - move the ECS service/task/clsuter creation in a different module
#

#Now we have the magic for making the ecs cluster HA by creating an APP autoscaling  target, attaching to it policies(for automatic scaling) and setting a min count of 2
resource "aws_appautoscaling_target" "count_to_target" {
  max_capacity = 5
  #we force it to go to 2 here-to test ASG works
  min_capacity = 2
  resource_id = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.hello_world.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

#create an autoscaling policy for memory
resource "aws_appautoscaling_policy" "memory" {
  name               = "count-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.count_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.count_to_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.count_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 80
  }
}

#create an autoscaling policy for cpu
resource "aws_appautoscaling_policy" "cpu" {
  name = "count-to-cpu"
  policy_type = "TargetTrackingScaling"
  resource_id = aws_appautoscaling_target.count_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.count_to_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.count_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}
#Outputs
output "ECS-ASG-ARN" {
  value = aws_ecs_cluster.main.id
}