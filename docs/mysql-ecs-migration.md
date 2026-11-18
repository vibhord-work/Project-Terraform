# RDS to ECS-hosted MySQL migration plan

## Current state

The current application backend receives DB connection details from the ECS task definition. It expects DB_HOST, DB_PORT, DB_NAME, DB_USER, and DB_PASSWORD. Terraform currently creates a private, encrypted RDS for MySQL instance and injects its endpoint and Secrets Manager credentials into the backend task.

The database contains application records (patients, appointments, doctors, nurses, bills, prescriptions, and related data). Treat it as persistent data even if this is a proof of concept.

## Target design

If the cost comparison justifies the move, run a single MySQL 8.0 container as an ECS EC2 service in the private subnets:

- One dedicated ECS container instance reserved for the database task.
- One separately managed encrypted EBS data volume attached to that database host and mounted at a stable host path such as /mnt/mysql-data.
- MySQL container mounts that host path at /var/lib/mysql.
- ECS placement constraint keeps the database task on the dedicated database container instance.
- Private DNS / Cloud Map service discovery gives the backend a stable database hostname.
- Security group permits TCP/3306 only from the backend ECS task security group.
- Credentials remain in Secrets Manager; never bake credentials into the image or task definition.
- EBS snapshots provide backup/recovery; test restores before cutover.

This design is single-instance and not highly available. It also adds EC2, EBS, snapshot, and operational responsibilities. Compare the full monthly cost against the current small RDS instance before deciding.

## Important ECS storage constraint

Do not use ECS-managed EBS volumes attached through an ECS service as the sole MySQL data store. AWS documents that EBS volumes attached to tasks managed by a service are deleted when those tasks terminate. A persistent MySQL service therefore needs a separately managed EBS volume with explicit attach, mount, backup, and recovery handling, or a managed database such as RDS.

Reference: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ebs-volumes.html

## Safe migration sequence

1. Keep the existing RDS instance, deletion protection, and Terraform prevent_destroy guard.
2. Create and verify a manual RDS snapshot.
3. Export the database with a consistent MySQL dump and securely transfer it to the private migration host. Do not store dumps in Git or public S3 buckets.
4. Provision the dedicated ECS database host, encrypted EBS data volume, task placement, Secrets Manager permissions, CloudWatch logs, and private security-group rules.
5. Start MySQL and restore the dump.
6. Compare schemas, table counts, key record counts, and application read/write tests.
7. Put the application into a short maintenance/read-only window, take a final consistent dump, restore changes, and validate again.
8. Update the backend task definition to use the private database service DNS name and new database credentials.
9. Deploy the backend and run application smoke tests.
10. Keep RDS intact for a rollback window. Only after explicit approval and successful backup/restore testing should RDS be decommissioned.

## Rollback

If validation or application smoke tests fail, point the backend task definition back to the existing RDS endpoint and redeploy. Do not delete the RDS instance or its snapshots during the rollback window.

## Current implementation status

This document is a migration plan only. The Terraform change in this branch does not delete, modify, or migrate RDS data. The database cutover must be implemented and tested as a separate reviewed change because it is stateful and potentially disruptive.
