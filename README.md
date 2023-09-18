# tf-aws-ex
This repository contains terraform code for creating an infrastructure according to [diagram.png](https://github.com/tudoricc/tf-aws-ex/blob/main/diagram.png)

## Requirements:

<details>
<summary>Requirements</summary>
    
- Terraform: [download page](https://developer.hashicorp.com/terraform/downloads)
    
- Access to an AWS Account and IAM User: [tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-build)
  
- Remote State (TBA)

</details>

## Layout decision breakdown

Each component is broken down in a separate module,rather than having a single TF module where you have all the logic for creating everything I broke it down in multiple modules,each containing  the following files: 
- main.tf - the file that creates all the resources
- provider.tf - the provider file
- var/eu-west-1.tfvars (the region variables file where I am creating that resource)

<details>
<summary>TLDR</summary>
Why break everything when you can break only 1 component?
</details>


## Repository Overview
<details>
<summary>Repository Structure</summary>

```text
.
├── alb
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── asg-ecs-cluster
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── aurora-db
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── diagram.png
├── ec2
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── iam-ecs-asg
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── README.md
├── s3bucket
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
├── single-ecs-cluster
│   ├── main.tf
│   ├── provider.tf
│   └── vars
│       └── eu-west-1.tfvars
└── vpc
    ├── main.tf
    ├── provider.tf
    └── vars
        └── eu-west-1.tfvars

```
</details>


## Breakdown of modules
The terraform modules can ran in a random order as long as the core modules are first run.

Core modules represent the backbone on which all the other resources are deployed on:
- vpc - you need a network where you create all the other resources
- iam-ecs-asg - the module that creates the iam rules used for autoscaling

As a rule of thumb: as long as you have a vpc the other modules do not rely on eachother and are created in the previously mentioned vpc(except the s3 bucket):

### EC2
Creates 3 ec2 instances spread across 3 AZs


### s3bucket
Creates an s3bucket

### aurora-db 
Creates a serverless Aurora DB cluster 

### alb
Creates an ALB to which we will assign the ECS Clusters from below

### single-ecs-cluster
Creates a ECS Cluster with 3 tasks in each AZ(depends on the alb and iam-ecs-asg modules to be ran first)

### asg-ecs-cluster
Creates an ECS cluster with an autoscaling policy to make it highly availableZ(depends on the alb and iam-ecs-asg modules to be ran first)


## How to run any module
```
#go in the directory of module you want to run
cd <<MODULE-DIRECTORY>>
terraform init
# Check to see what would happen,
terraform plan --var-file="./vars/<cluster>.tfvars"
# Create resources
terraform apply --var-file="./vars/<cluster>.tfvars"

```
