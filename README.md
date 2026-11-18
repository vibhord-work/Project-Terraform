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

## Database migration safety

RDS is currently private, encrypted, deletion-protected, and protected by Terraform prevent_destroy. Do not remove these safeguards or destroy RDS as part of the NAT migration.

The application stores patient, appointment, and related hospital records. Before moving MySQL into ECS, take and verify an RDS snapshot, export the database, restore into a persistent ECS-hosted MySQL target, validate schema/row counts/application reads and writes, then switch the backend connection. Keep RDS available for rollback until the new database is proven.

Important ECS storage limitation: ECS-managed EBS volumes attached to tasks maintained by an ECS service are deleted when those tasks terminate. Do not use that service volume feature as the only persistent database storage. A containerized MySQL design needs a separately managed persistent data volume and a deliberate single-instance placement/backup/recovery design. This has operational trade-offs and may not be cheaper than the existing small RDS instance once EC2, EBS snapshots, and maintenance are included.

## Terraform workflow

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Apply only an inspected and approved plan. Never commit credentials, state files, real tfvars, secret values, or plan files.
