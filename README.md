# ECS on EC2 Cluster with Shared EFS (Terraform)

Terraform code that deploys an EC2-backed ECS cluster with an ALB into an existing VPC in `us-east-1`, plus an EFS file
system mounted on every node at `/mnt/efs`, and two small example NGINX services (one using the EFS mount as a volume).

> **Status:** legacy reference (2026, single re-published commit of older code), written for Terraform 0.11-era syntax (`"${...}"` interpolation, `type = "string"`, `tags {}` blocks), not actively maintained. Review and update providers/syntax before using.

## Architecture

Root module (`main.tf`, `variables.tf`; `outputs.tf` is empty):

- ECS cluster `var.ecs_cluster`; `aws_key_pair` `<cluster>-key` from an embedded public key.
- IAM role `<cluster>-role` (trusted by ECS and EC2) with `AmazonEC2ContainerServiceRole`, `AmazonEC2ContainerServiceforEC2Role`,
  `AmazonSSMFullAccess`, `CloudWatchFullAccess`, `AmazonElasticFileSystemFullAccess`; instance profile.
- SGs: cluster (22/80/443 from `10.0.0.0/16`), ALB (80/443 from `0.0.0.0/0`), EFS (2049 from `10.0.0.0/16`).
- ALB in `subnet_1..3`, HTTP:80 listener, target group `<cluster>-target-group`.
- EFS (general purpose, transition to IA after 7 days) with mount targets in `subnet_efs`, `subnet_efs2`, `subnet_efs3`.
- Launch configuration (hardcoded `us-east-1` ECS AMI, `var.instance_type`, 30 GB gp2) whose user data joins the cluster,
  installs `amazon-efs-utils`, looks up the EFS ID by name, mounts it at `/mnt/efs` (+ `/etc/fstab`) and installs the SSM agent.
- Auto Scaling group in `subnet_4..6` sized by variables.

Separate root modules under `contenedores/` (apply after the cluster):

- `nginx-demo/`: ECS service `nginx` (`nginx:latest`, host port 80) with log group `/ecs-demo/nginx`.
- `nginx-efs-instance/`: ECS service with a `host_path` volume `/mnt/efs` mounted in the container at `/var/ww/html`.
- Both hardcode the service role ARN and target group ARN, e.g.
  `arn:aws:iam::<AWS_ACCOUNT_ID>:role/<cluster>-role` and
  `arn:aws:elasticloadbalancing:us-east-1:<AWS_ACCOUNT_ID>:targetgroup/<cluster>-target-group/<TG_ID>` — edit them first.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `access_key` / `secret_key` | AWS credentials for the provider (all modules) | none (required) |
| `ecs_cluster` | Cluster name / resource prefix (all modules) | none (required) |
| `vpc_id` | Existing VPC ID (expected CIDR `10.0.0.0/16`) | none (required) |
| `subnet_1..3` | Public subnets for the ALB | none (required) |
| `subnet_4..6` | Subnets for the ECS instances | none (required) |
| `subnet_efs`, `subnet_efs2`, `subnet_efs3` | Subnets for the EFS mount targets | none (required) |
| `min_instance_size` / `desired_capacity` / `max_instance_size` | ASG sizing | none (required) |
| `instance_type` | EC2 instance type | none (required) |

## Usage

```bash
terraform init && terraform apply -var-file=my.tfvars          # cluster, ALB, EFS, ASG
cd contenedores/nginx-efs-instance                              # after editing the hardcoded ARNs
terraform init && terraform apply -var 'ecs_cluster=<CLUSTER>'  # plus credentials
```

No backend is configured anywhere; each directory keeps its own local state. Keep `*.tfvars` with credentials out of git.

## Security notes

- EFS is created without `encrypted = true` (no encryption at rest); `/mnt/efs` is `chmod 777`.
- Instance role has broad managed policies (`AmazonSSMFullAccess`, `CloudWatchFullAccess`, `AmazonElasticFileSystemFullAccess`).
- The ALB SG (80/443 from `0.0.0.0/0`) is also attached to the instances; ALB is HTTP only.
- Security groups assume a `10.0.0.0/16` VPC; hardcoded ARNs and AMI ID make the service modules non-portable.
- The EFS volume is mounted at `/var/ww/html` (typo, and not the NGINX web root), so the demo does not serve EFS content as-is.
- AWS credentials as plain variables, local state, `nginx:latest` mutable tag, deprecated `aws_launch_configuration` and legacy ECS service role.

## Cleanup

```bash
(cd contenedores/nginx-efs-instance && terraform destroy)
(cd contenedores/nginx-demo && terraform destroy)
terraform destroy -var-file=my.tfvars
```

## License

MIT — see [LICENSE](LICENSE).
