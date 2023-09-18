#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "environment" {}



#in case we want to associate it to the alb created previously
data "terraform_remote_state" "alb" {
  backend = "local"

 config = {
    path = "${path.module}/../alb/terraform.tfstate"
  }
}
#module variables
locals {
  alb_arn = data.terraform_remote_state.alb.outputs.alb_arn
}

#################################################################
# THis module can do a lot more than just the iam roles for ecs
#################################################################


#creating a IAM role for the ecs service to allow it to assumeRole
resource "aws_iam_role" "ecs_service" {
  name = "ecs-service"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}


#These are the policies needed for the ASG to function
data "aws_iam_policy_document" "ecs_service_elb" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets"
    ]
    #in theory we should add it for only that LB,will uncomment later
    resources = [
      local.alb_arn
    ]
  }
}

#Adding more policies for the ASG to function properly,this is a data block(doesn't create any resources yet)
data "aws_iam_policy_document" "ecs_service_standard" {

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeTags",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "*"
    ]
  }
}

#Docs: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html
#The below policies are needed  for service autoscaling,this is a data block(doesn't create any resources yet)
data "aws_iam_policy_document" "ecs_service_scaling" {

  statement {
    effect = "Allow"

    actions = [
      "application-autoscaling:*",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
      "iam:CreateServiceLinkedRole",
      "sns:CreateTopic",
      "sns:Subscribe",
      "sns:Get*",
      "sns:List*"
    ]

    resources = [
      "*"
    ]
  }
}

#Now creating the resources for the above policies
resource "aws_iam_policy" "ecs_service_elb" {
  name = "ecs-access-elb-policy"
  path = "/"
  description = "Allow access to the service elb"

  policy = data.aws_iam_policy_document.ecs_service_elb.json
}

resource "aws_iam_policy" "ecs_service_standard" {
  name = "ecs-actions-policy"
  path = "/"
  description = "Allow standard ecs actions"

  policy = data.aws_iam_policy_document.ecs_service_standard.json
}

resource "aws_iam_policy" "ecs_service_scaling" {
  name = "ecs-scaling-policy"
  path = "/"
  description = "Allow ecs service scaling"

  policy = data.aws_iam_policy_document.ecs_service_scaling.json
}

resource "aws_iam_role_policy_attachment" "ecs_service_elb" {
  role = aws_iam_role.ecs_service.name
  policy_arn = aws_iam_policy.ecs_service_elb.arn
}

resource "aws_iam_role_policy_attachment" "ecs_service_standard" {
  role = aws_iam_role.ecs_service.name
  policy_arn = aws_iam_policy.ecs_service_standard.arn
}

resource "aws_iam_role_policy_attachment" "ecs_service_scaling" {
  role = aws_iam_role.ecs_service.name
  policy_arn = aws_iam_policy.ecs_service_scaling.arn
}


#Output
output "ecs-iam-role" {
  value = aws_iam_role.ecs_service.arn
}