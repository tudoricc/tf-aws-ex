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


#calling the S3 bucket terraform module to create the bucket with a specific name
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = local.s3-bucket-name
  #we make it private because security
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = true
  }
}