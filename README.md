# Project Terraform

Terraform configuration for the HospitalDBMS AWS proof of concept.

## Network architecture

- Custom VPC with public and private subnets across two Availability Zones.
- Internet-facing Application Load Balancer in public subnets.
- Jenkins, ECS container instances, ECS tasks, and RDS remain private.
- A cost-optimized EC2 NAT instance (t3.micro) can provide outbound connectivity to private subnets.
- An S3 Gateway VPC Endpoint is created for private S3 access without an endpoint hourly charge.
- RDS MySQL remains provisioned as the rollback source. A dedicated ECS EC2 host now runs the MySQL target with a separately managed encrypted EBS data volume. The backend remains on RDS by default; switch it only after data import and verification by setting use_ecs_mysql = true.

## NAT Gateway to NAT Instance migration

The configuration supports a staged cutover. Do not disable the existing NAT Gateway until the NAT instance is running and tested.

### Stage 1 — Create NAT instance, retain NAT Gateway

Set these values in terraform.tfvars:

```hcl
enable_nat_gateway                         = true
enable_nat_instance                        = true
nat_instance_type                          = "t3.micro"
route_private_traffic_through_nat_instance = false
```

Run from the repository root:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Review the plan. It should create the NAT instance, EIP, IAM role/profile, and security group while retaining the existing NAT Gateway and its routes. Apply only after review.

### Stage 2 — Switch private routes to NAT instance

After the NAT instance has completed user-data initialization and is reachable through Systems Manager, set:

```hcl
route_private_traffic_through_nat_instance = true
enable_nat_gateway                         = true
enable_nat_instance                        = true
```

Run and review a new plan, then apply. Verify from private Jenkins and ECS hosts that DNS resolution, HTTPS access to GitHub, AWS APIs, ECR pulls, CloudWatch Logs, and SSM continue to work. Check NAT instance CPU/network metrics and system logs.

### Stage 3 — Remove NAT Gateway

Only after the route cutover and workload tests succeed, set:

```hcl
enable_nat_gateway                         = false
enable_nat_instance                        = true
route_private_traffic_through_nat_instance = true
```

Review the plan to ensure only the NAT Gateway and its Elastic IP are removed and private routes remain pointed at the NAT instance. Apply after approval.

### NAT instance operational notes

- NAT instance is in a public subnet with an Elastic IP; private workloads remain private and receive no public IPs.
- The NAT instance has no inbound SSH rule. Use Systems Manager Session Manager for administration.
- Source/destination checking is disabled and Linux IPv4 forwarding plus iptables masquerading are configured by user data.
- This is a single-instance, single-AZ egress path and a single point of failure. It is appropriate for a cost-sensitive POC, not a highly available production network.
- The NAT instance can become a throughput bottleneck. Monitor CPU, network packets/bytes, connection tracking, and application timeouts.
- A NAT instance still incurs EC2, EBS, public IPv4, and data-transfer charges. A t3.micro is a starting point, not a throughput guarantee.

## ECS MySQL migration safety

Terraform now provisions a dedicated private ECS EC2 host, a separately managed encrypted gp3 data volume, a MySQL 8.0 ECS service, Cloud Map DNS (mysql.db.internal), Secrets Manager credentials, and CloudWatch logging. The MySQL task is pinned to the dedicated host and mounts /mnt/mysql-data at /var/lib/mysql.

The backend remains connected to RDS by default (`use_ecs_mysql = false`). Do not switch it until a verified RDS snapshot/export/import and application validation are complete. Set `use_ecs_mysql = true` only in a separate reviewed apply after the ECS database contains the verified application data. Keep RDS deletion protection and Terraform prevent_destroy throughout the rollback window.

The MySQL host and EBS data volume are single-AZ and are not highly available. ECS-managed EBS volumes attached to service tasks are not used as the persistent store; the separately managed EBS volume is protected with prevent_destroy. Terraform state contains generated database credentials, so use encrypted, access-controlled remote state and never commit local state or secret values.

## Terraform workflow

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Apply only an inspected and approved plan. Never commit credentials, state files, real tfvars, secret values, or plan files.
