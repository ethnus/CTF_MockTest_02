# Mock Test 02 - Container Orchestration & Service Discovery
# Focus: ECS, Application Load Balancer, Service Mesh, Container Networking

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "ethnus-mocktest-02"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "training"
}

# Local values for common tags and configurations
locals {
  common_tags = {
    Project     = "EthnusAWS-MockTest02"
    Environment = var.environment
    Owner       = "Training"
    TestType    = "ContainerOrchestration"
  }
}

# Data sources for AZ and AMI lookup
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-igw"
  })
}

# Public Subnets for ALB
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

# Private Subnets for ECS Tasks
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnet internet access
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${var.prefix}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-alb-sg"
  })
}

# CHALLENGE 1: Security group for ECS tasks - intentionally restrictive
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.prefix}-ecs-tasks-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for ECS tasks"

  # Intentionally missing ingress rule from ALB
  # Should allow traffic from ALB security group on port 3000

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Intentionally missing tags
  # tags = merge(local.common_tags, {
  #   Name = "${var.prefix}-ecs-tasks-sg"
  # })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  # CHALLENGE 2: Intentionally missing access logs configuration
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs.bucket
  #   enabled = true
  # }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-alb"
  })
}

# Target Group for ECS Service
resource "aws_lb_target_group" "app" {
  name     = "${var.prefix}-app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # CHALLENGE 3: Intentionally wrong health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/wrong-path" # Should be "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-app-tg"
  })
}

# ALB Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.app.arn
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-app-listener"
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-ecs-cluster"
  })
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.prefix}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-ecs-logs"
  })
}

# Data source to get existing ECS task execution role
# AWS Academy Learner Lab provides this role by default
data "aws_iam_role" "ecs_task_execution_role" {
  name = "LabRole"
}

# Data source to get existing ECS task role 
# Using the same LabRole since we can't create custom roles
# Data source to get existing ECS task role 
# Using the same LabRole since we can't create custom roles
data "aws_iam_role" "ecs_task_role" {
  name = "LabRole"
}

# Note: Custom IAM policies removed due to AWS Academy Learner Lab limitations
# CHALLENGE 4: Service Discovery would normally require custom permissions

# Note: Service Discovery removed due to AWS Academy Learner Lab limitations
# CHALLENGE 5: Service Discovery would normally be configured here
# In this simplified version, we'll use ALB health checks for service discovery

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  # CHALLENGE 6: Intentionally insufficient memory
  memory             = 512 # Valid minimum for 256 CPU, but could be optimized to 1024 for better performance
  execution_role_arn = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = data.aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "webapp"
      image = "nginx:alpine"

      portMappings = [
        {
          containerPort = 80
          # CHALLENGE 7: Wrong host port mapping
          hostPort = 80 # Should be 3000 to match target group
          protocol = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      # CHALLENGE 8: Missing health check configuration
      # healthCheck = {
      #   command = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      #   interval = 30
      #   timeout = 5
      #   retries = 3
      #   startPeriod = 60
      # }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-app-task-def"
  })
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.prefix}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  # CHALLENGE 9: Intentionally low desired count
  desired_count = 0 # Should be at least 2 for high availability
  launch_type   = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "webapp"
    container_port   = 80
  }

  # Note: Service registries removed due to Service Discovery limitations
  # CHALLENGE 5: Service Discovery would normally be configured here

  # CHALLENGE 10: Missing deployment configuration for rolling updates
  # deployment_configuration {
  #   maximum_percent         = 200
  #   minimum_healthy_percent = 100
  # }

  depends_on = [
    aws_lb_listener.app
  ]

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-app-service"
  })
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name = "${var.prefix}-ecs-autoscaling-target"
  })
}

# CHALLENGE 11: Auto Scaling Policy with wrong metric
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "${var.prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    # Intentionally too low CPU threshold
    target_value = 30.0 # Should be around 70-80% for production workloads

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# S3 Bucket for ALB Access Logs (referenced but not created properly)
# CHALLENGE 12: Missing S3 bucket for ALB access logs
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# resource "aws_s3_bucket" "alb_logs" {
#   bucket = "${var.prefix}-alb-access-logs-${random_string.bucket_suffix.result}"
#   
#   tags = merge(local.common_tags, {
#     Name = "${var.prefix}-alb-logs"
#   })
# }

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}
