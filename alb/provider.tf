terraform {

  required_providers {

    aws = {

      source = "hashicorp/aws"

      version = ">= 4.66.0"

    }

  }

}


# module "ec2-instance" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "5.5.0"
# }

