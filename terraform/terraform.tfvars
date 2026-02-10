# AWS Configuration
aws_region   = "us-east-1"
project_name = "my-app"
environment  = "production"

# EKS Cluster Configuration
cluster_name    = "my-app-eks-cluster"
cluster_version = "1.28"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# Node Group Configuration
node_group_desired_size = 2
node_group_min_size     = 1
node_group_max_size     = 4
node_instance_types     = ["t3.medium"]
node_disk_size          = 20

# ECR Configuration
ecr_repository_name = "my-app"
ecr_scan_on_push    = true

# Application Configuration
app_name      = "my-app"
app_namespace = "default"
app_replicas  = 2
app_port      = 3000

# Feature Flags
enable_cluster_autoscaler = true
enable_metrics_server     = true
enable_alb_controller     = true

# Additional Tags
tags = {
  Team = "DevOps"
  Cost = "Project-A"
}