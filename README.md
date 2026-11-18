# Project Terraform

Terraform configuration for the HospitalDBMS proof of concept on AWS.

## Architecture

- A custom VPC with public and private subnets across two Availability Zones.
- An internet-facing Application Load Balancer in the public subnets.
- An ECS cluster using the EC2 launch type, an Auto Scaling Group, and an ECS capacity provider.
- Frontend and backend ECS services running in private subnets.
- An encrypted, private Amazon RDS for MySQL instance.
- Amazon ECR repositories for application images.
- CloudWatch log groups, Container Insights, and monitoring resources.
- A private Jenkins EC2 instance managed through AWS Systems Manager Session Manager.
- SSM documents and supporting resources for webhook-triggered Jenkins jobs.

Resource names and default tags are derived from `project_name` and `environment`.

## Prerequisites

- Terraform version **1.17.0** (as constrained in `versions.tf`).
- AWS CLI configured with credentials for the target account.
- An AWS identity permitted to create and manage the resources in this configuration.
- Required pre-existing Secrets Manager secrets referenced by the configuration. Confirm their names and JSON keys in the relevant `.tf` files before planning.
- Application images available in the ECR repositories before expecting ECS tasks to become healthy.

Do not commit AWS credentials, Terraform state, real `*.tfvars` files, secret values, or plan files.

## Configure

1. Clone this repository and enter its root directory.
2. Copy the example variables file:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Review and edit `terraform.tfvars` for the target environment.
4. Confirm the AWS account and region:

   ```bash
   aws sts get-caller-identity
   aws configure get region
   ```

The current defaults target `us-east-1`. The Availability Zone values in the example must belong to the selected region.

## Validate and plan

Run Terraform from the repository root, where the root configuration files are located:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Review the complete plan, especially changes to RDS, networking, IAM, load balancers, and ECS services. The RDS resource has deletion protection and a Terraform `prevent_destroy` lifecycle guard. Do not remove those safeguards merely to make a plan succeed.

Apply only after reviewing and approving the plan:

```bash
terraform apply tfplan
```

## AWS Systems Manager access

The Jenkins instance role and ECS container-instance role attach `AmazonSSMManagedInstanceCore`. ECS container instances are launched in private subnets; the current route-table configuration sends private-subnet outbound traffic through a NAT Gateway.

For Session Manager connectivity, verify all of the following:

- The instance has the expected IAM instance profile.
- The SSM Agent is installed and running.
- The instance can reach the regional Systems Manager endpoints over HTTPS (through NAT or VPC interface endpoints).
- The operator's IAM identity is allowed to start and manage Session Manager sessions.

The IAM attachment in this repository grants the instance role the required SSM permissions; it does not independently guarantee agent health or network reachability.

## Operational notes

- The ECS cluster uses the EC2 capacity provider and an Auto Scaling Group.
- ECS task definitions currently refer to versioned ECR image tags. Update those references through the normal deployment workflow when publishing new images.
- RDS is private, encrypted, deletion-protected, and configured with a final snapshot.
- A single NAT Gateway is enabled by default to reduce POC cost; it is a single-AZ egress design and is not a highly available production pattern.
- Review AWS costs before applying. NAT Gateways, EC2 instances, RDS, ALB, EBS, CloudWatch, and data transfer can incur charges.

## Cleanup

Do not run `terraform destroy` as a routine cleanup step. Review the plan and data-retention requirements first. RDS has explicit deletion safeguards and may require a deliberate, separately reviewed decommissioning procedure.
