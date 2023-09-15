#variables that will be imported for each region/cluster
variable "region_aws" {}
variable "environment" {}
# Configure the AWS Provider
provider "aws" {
  region = var.region_aws
}
#module variables
locals {
  s3-bucket-name = "sonar-s3-${var.region_aws}-${var.environment}"
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.s3-bucket-name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}