# Ethnus AWS Mock Test Project - Container Orchestration

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-Infrastructure-blue)](https://terraform.io/)
[![Difficulty](https://img.shields.io/badge/Difficulty-Advanced-red)](https://github.com)

A comprehensive AWS container orchestration challenge designed to test cloud engineering skills in ECS, Application Load Balancers, and Service Discovery in a CTF (Capture The Flag)-type environment.

## 🎯 Challenge Overview

This is a **Capture The Flag (CTF)** challenge focused on AWS container orchestration and microservices architecture. Competitors will deploy a deliberately misconfigured containerized application infrastructure and must identify and fix **12 specific issues** to complete all challenges.

### What Gets Deployed
- **VPC Infrastructure** with public and private subnets (networking & routing issues)
- **Application Load Balancer** with target groups (integration & health check issues)
- **ECS Fargate Cluster** with containerized services (configuration & scaling issues)
- **Service Discovery** for microservice communication (DNS & routing policy issues)
- **Auto Scaling** configuration for dynamic scaling (threshold & policy issues)
- **Security Groups** for network security (missing rules & governance issues)
- **IAM Roles** for service permissions (missing Service Discovery permissions)
- **CloudWatch Logs** for container logging

### The 12 Challenges
After deployment, the evaluation will show **12 INCOMPLETE** challenges:

1. **Network security: task communication** - Configure proper security group rules for container access
2. **Resource governance: security groups** - Ensure compliance with organizational tagging standards
3. **Load balancer: health verification** - Fix health check configuration for proper service detection
4. **Container platform: service permissions** - Enable Service Discovery access for microservices
5. **Service discovery: routing optimization** - Configure optimal DNS routing policies
6. **Performance optimization: memory allocation** - Adjust container resource limits for proper operation
7. **Container configuration: port mapping** - Align container ports with load balancer expectations
8. **Application monitoring: health checks** - Implement container-level health verification
9. **Service orchestration: availability** - Ensure adequate service replica count for high availability
10. **Deployment strategy: rolling updates** - Configure proper deployment parameters for zero-downtime updates
11. **Auto scaling: performance thresholds** - Optimize scaling triggers for production workloads
12. **Infrastructure foundation: access logging** - Complete load balancer observability configuration

This challenge simulates a real-world AWS environment where you'll need to deploy, secure, and troubleshoot a containerized microservices architecture while working within the constraints of AWS Academy Learner Lab.

## 🏗️ Architecture

The project implements a multi-tier containerized architecture with the following components:

```
┌────────────────────────────────────────────────────────────────┐
│                           Internet                              │
└─────────────────────────┬──────────────────────────────────────┘
                          │
┌─────────────────────────▼──────────────────────────────────────┐
│                    Internet Gateway                            │
└─────────────────────────┬──────────────────────────────────────┘
                          │
┌─────────────────────────▼──────────────────────────────────────┐
│                  Public Subnets (Multi-AZ)                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Application Load Balancer                    │   │
│  │              (Health Checks)                           │   │
│  └─────────────────────┬───────────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────────┘
                          │
┌─────────────────────────▼──────────────────────────────────────┐
│                 Private Subnets (Multi-AZ)                     │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │   ECS Fargate    │  │   ECS Fargate    │  │     NAT      │  │
│  │   Task 1         │  │   Task 2         │  │   Gateway    │  │
│  │  ┌─────────────┐ │  │  ┌─────────────┐ │  │              │  │
│  │  │  Container  │ │  │  │  Container  │ │  │              │  │
│  │  │  (Node.js)  │ │  │  │  (Node.js)  │ │  │              │  │
│  │  └─────────────┘ │  │  └─────────────┘ │  │              │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Service Discovery                          │   │
│  │           (Cloud Map DNS)                              │   │
│  │         webapp.mocktest-02.local                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                      AWS Services                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ CloudWatch  │  │ Auto Scaling│  │       S3 Bucket         │  │
│  │    Logs     │  │   Groups    │  │   (ALB Access Logs)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### Required Access
- **AWS Academy Learner Lab** account with active session
- Access to AWS CLI (configured with Learner Lab credentials)
- Basic understanding of container orchestration and AWS services

### Required Tools
- **Terraform** >= 1.5.0 (auto-installed by deploy script)
- **AWS CLI** >= 2.0
- **jq** (for evaluation script)
- **bash** (for running scripts)

### Required Knowledge
- AWS fundamentals (VPC, ECS, ALB, IAM)
- Container concepts (Docker, orchestration)
- Basic Terraform concepts
- Service Discovery and DNS
- Load balancing concepts
- Command line proficiency

## 🚀 Quick Start

### For Competitors (Challenge Takers)

1. **Setup Workspace (AWS CloudShell)**
   ```bash
   # Create workspace directory with sufficient storage
   sudo mkdir -p /workspace
   sudo chown cloudshell-user:cloudshell-user /workspace
   cd /workspace
   ```

2. **Clone Repository and Navigate**
   ```bash
   # Clone the challenge repository
   git clone https://github.com/ethnus/CTF_MockTest_02.git
   cd CTF_MockTest_02/scripts/
   ```

3. **Deploy Infrastructure**
   ```bash
   # Set your preferences (optional)
   export PREFIX="ethnus-mocktest-02"
   export REGION="us-east-1"
   
   # Deploy the challenge environment
   bash deploy.sh
   ```

   **Quick One-Liner:**
   ```bash
   sudo mkdir -p /workspace && sudo chown cloudshell-user:cloudshell-user /workspace && cd /workspace && git clone https://github.com/ethnus/CTF_MockTest_02.git && cd CTF_MockTest_02/scripts/ && bash deploy.sh && bash eval.sh
   ```

4. **Run Initial Evaluation**
   ```bash
   bash eval.sh
   ```
   You should see multiple `INCOMPLETE` status items - these are your challenges!

5. **Start Troubleshooting**
   - Use AWS Console, CLI, and documentation
   - Fix configurations one by one
   - Re-run `bash eval.sh` to check progress

6. **Complete the Challenge**
   - All 12 checks should show `ACCEPTED`
   - The containerized application will be fully functional

### For Instructors (Challenge Administrators)

1. **Setup and Deploy Competitor Environment**
   ```bash
   # Setup workspace directory (AWS CloudShell)
   sudo mkdir -p /workspace
   sudo chown cloudshell-user:cloudshell-user /workspace
   cd /workspace
   
   # Clone the challenge repository
   git clone https://github.com/ethnus/CTF_MockTest_02.git
   cd CTF_MockTest_02/scripts/
   
   # Deploy the infrastructure
   bash deploy.sh
   ```

2. **Verify Challenge State**
   ```bash
   bash eval.sh
   # Should show intentional misconfigurations
   ```

3. **Monitor Competitor Progress**
   Competitors can run `eval.sh` anytime to check their progress

4. **Provide Hints** (if needed)
   Each challenge has specific learning objectives (see Challenge Details below)

5. **Reset Environment** (if needed)
   ```bash
   # Fix all issues for demonstration
   bash remediate.sh
   
   # Completely clean up
   bash teardown.sh
   ```

## 📊 Challenge Structure

The evaluation script tests **12 key areas** of container orchestration and microservices architecture:

| # | Challenge | Focus Area | Learning Objective |
|---|-----------|------------|-------------------|
| 1 | Network security: task communication | Security | Configure security group rules for container communication |
| 2 | Resource governance: security groups | Compliance | Apply organizational tagging standards |
| 3 | Load balancer: health verification | Networking | Configure proper health check endpoints |
| 4 | Container platform: service permissions | IAM | Enable Service Discovery permissions for containers |
| 5 | Service discovery: routing optimization | DNS | Configure optimal DNS routing policies |
| 6 | Performance optimization: memory allocation | Performance | Set appropriate container resource limits |
| 7 | Container configuration: port mapping | Configuration | Align container and load balancer port settings |
| 8 | Application monitoring: health checks | Monitoring | Implement container-level health verification |
| 9 | Service orchestration: availability | Reliability | Configure adequate service replica count |
| 10 | Deployment strategy: rolling updates | DevOps | Enable zero-downtime deployment configurations |
| 11 | Auto scaling: performance thresholds | Scalability | Optimize auto scaling triggers |
| 12 | Infrastructure foundation: access logging | Observability | Complete load balancer logging setup |

## 🛠️ Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy.sh` | Deploy challenge infrastructure | `bash deploy.sh` |
| `eval.sh` | Evaluate current state (12 checks) | `bash eval.sh` |
| `remediate.sh` | Fix all issues (instructor use) | `bash remediate.sh` |
| `teardown.sh` | Complete cleanup | `bash teardown.sh` |

## 🌐 Environment Setup

### AWS Environment Requirements
```bash
# Verify AWS CLI access (usually automatic in Learner Lab)
aws sts get-caller-identity

# IMPORTANT: AWS CloudShell Setup (Recommended)
# Create workspace directory with more storage (home ~ is only 1GB)
sudo mkdir -p /workspace
sudo chown cloudshell-user:cloudshell-user /workspace
cd /workspace

# Install jq if not available (required for eval.sh)
sudo yum install jq -y  # For Amazon Linux/CloudShell
# OR: sudo apt-get update && sudo apt-get install jq -y  # For Ubuntu
```

### Supported Environments
- **AWS CloudShell** (Recommended)
- **EC2 instances** with appropriate IAM roles
- **Local environment** with AWS CLI configured
- **WSL on Windows** with AWS CLI

### Complete Setup Example
```bash
# Complete setup from scratch in AWS CloudShell
sudo mkdir -p /workspace
sudo chown cloudshell-user:cloudshell-user /workspace
cd /workspace

git clone https://github.com/ethnus/CTF_MockTest_02.git
cd CTF_MockTest_02/scripts/
bash deploy.sh
bash eval.sh
```

## 🔧 Troubleshooting Guide

### Common Issues

**"No space left on device" or storage issues in AWS CloudShell**
```bash
# AWS CloudShell home directory (~) is limited to 1GB
# Use /workspace directory instead (has more storage)
sudo mkdir -p /workspace
sudo chown cloudshell-user:cloudshell-user /workspace
cd /workspace
# Then clone and run from here
```

**"terraform not found"**
```bash
# The deploy script auto-installs terraform
bash deploy.sh
```

**"AWS credentials not configured"**
```bash
# Configure AWS CLI with your Learner Lab credentials
aws configure
# Or use environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_SESSION_TOKEN="your-token"
```

**"jq command not found"**
```bash
# Install jq for your system
# Ubuntu/Debian:
sudo apt-get install jq
# macOS:
brew install jq
# Windows: Download from https://jqlang.github.io/jq/
```

**ECS Tasks not starting**
- This is expected! The configuration is intentionally misconfigured
- Check ECS Console for task definitions and service configurations
- Review CloudWatch logs for container startup errors
- Verify security group rules and port mappings

**Load Balancer health checks failing**
- Expected behavior with misconfigured health check paths
- Use ALB Console to review target group health
- Check container port mappings and security groups

### Investigation Tips

1. **Use AWS Console**
   - Check ECS Cluster and Service status
   - Review Load Balancer target group health
   - Examine Service Discovery configuration
   - Verify Auto Scaling group settings
   - Review CloudWatch container logs

2. **Use AWS CLI**
   ```bash
   # Check ECS service details
   aws ecs describe-services --cluster ethnus-mocktest-02-cluster --services ethnus-mocktest-02-app-service
   
   # List ECS tasks
   aws ecs list-tasks --cluster ethnus-mocktest-02-cluster
   
   # Check Load Balancer target health
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   
   # Review Service Discovery services
   aws servicediscovery list-services
   ```

3. **Container Debugging**
   ```bash
   # View ECS task logs
   aws logs describe-log-groups --log-group-name-prefix "/ecs/ethnus-mocktest-02"
   
   # Check task definition details
   aws ecs describe-task-definition --task-definition ethnus-mocktest-02-app
   
   # View Auto Scaling activities
   aws application-autoscaling describe-scaling-activities --service-namespace ecs
   ```

4. **Read Error Messages**
   - The eval script provides specific error context
   - Look for patterns in failed health checks
   - Use AWS documentation for ECS and ALB troubleshooting

## 🎓 Learning Objectives

Upon completion, you will demonstrate proficiency in:

- **Container Orchestration** with ECS Fargate
- **Application Load Balancer** configuration and health checks
- **Service Discovery** for microservices communication
- **Auto Scaling** policies and thresholds
- **Network Security** with VPC and Security Groups
- **IAM Roles** and service permissions
- **Infrastructure as Code** with Terraform
- **Monitoring and Logging** for containerized applications
- **Zero-downtime Deployments** and rolling updates
- **Resource Tagging** and governance compliance

## 💡 Best Practices Reinforced

- **Containerization Best Practices** - Proper resource allocation and health checks
- **Microservices Architecture** - Service discovery and inter-service communication
- **High Availability** - Multi-AZ deployment and auto scaling
- **Security by Design** - Least privilege access and network segmentation
- **Observability** - Comprehensive logging and monitoring
- **Infrastructure as Code** - Versioned, repeatable deployments
- **Cost Optimization** - Efficient resource utilization with auto scaling
- **Operational Excellence** - Automated deployment and scaling strategies

---

<details>
<summary><strong>🚨 SPOILER ALERT - Challenge Details & Solutions</strong></summary>

> **⚠️ WARNING**: The following section contains detailed challenge descriptions and solution hints. Only expand if you're an instructor or have completed the challenge!

### Summary Table of Fixes

| # | Challenge | Issue | Solution | AWS Service |
|---|-----------|-------|----------|-------------|
| 1 | Network security: task communication | ECS tasks security group missing ingress rule from ALB | Add ingress rule allowing traffic from ALB security group on port 3000 | Security Groups |
| 2 | Resource governance: security groups | ECS tasks security group missing required tags | Add standard organizational tags including `Name` tag | Security Groups |
| 3 | Load balancer: health verification | Target group health check path incorrect | Change health check path from `/wrong-path` to `/health` | ALB Target Groups |
| 4 | Container platform: service permissions | ECS task role missing Service Discovery permissions | Add `servicediscovery:RegisterInstance` and `servicediscovery:DeregisterInstance` permissions | IAM |
| 5 | Service discovery: routing optimization | Service Discovery routing policy set to WEIGHTED | Change routing policy from `WEIGHTED` to `MULTIVALUE` | Service Discovery |
| 6 | Performance optimization: memory allocation | ECS task definition memory too low (256MB) | Increase memory from 256MB to 512MB | ECS Task Definition |
| 7 | Container configuration: port mapping | Container port mismatch with target group | Change container port from 80 to 3000 to match target group | ECS Task Definition |
| 8 | Application monitoring: health checks | Missing container health check configuration | Add container health check command for port 3000/health endpoint | ECS Task Definition |
| 9 | Service orchestration: availability | ECS service desired count set to 0 | Increase desired count from 0 to 2 for high availability | ECS Service |
| 10 | Deployment strategy: rolling updates | Missing deployment configuration | Add deployment configuration with proper maximum_percent and minimum_healthy_percent | ECS Service |
| 11 | Auto scaling: performance thresholds | CPU scaling threshold too low (30%) | Increase CPU threshold from 30% to 75% for production workloads | Auto Scaling Policy |
| 12 | Infrastructure foundation: access logging | S3 bucket for ALB access logs not created | Create S3 bucket and enable ALB access logging | S3, ALB |

## 🎯 Detailed Challenge Breakdown

### Challenge 1: Network Security - Task Communication
**Issue**: Container tasks cannot receive traffic from the load balancer
**Focus**: Configure proper security group rules for container access
**Best Practices**: 
• Implement least privilege network access
• Allow only necessary traffic between services
• Use security group references for dynamic IPs

### Challenge 2: Resource Governance - Security Groups
**Issue**: Security groups missing organizational compliance tags
**Focus**: Ensure compliance with organizational tagging standards
**Best Practices**:
• Apply consistent resource tagging strategies
• Enable resource tracking and cost allocation
• Maintain governance across all network resources

### Challenge 3: Load Balancer - Health Verification
**Issue**: Health checks failing due to incorrect endpoint configuration
**Focus**: Fix health check configuration for proper service detection
**Best Practices**:
• Configure appropriate health check endpoints
• Set proper timeouts and thresholds
• Implement meaningful health indicators

### Challenge 4: Container Platform - Service Permissions
**Issue**: ECS tasks cannot register with Service Discovery
**Focus**: Enable Service Discovery access for microservices
**Best Practices**:
• Grant minimal required permissions for service registration
• Enable automatic service discovery for containers
• Implement proper IAM role separation

### Challenge 5: Service Discovery - Routing Optimization
**Issue**: DNS routing policy not optimized for multi-instance services
**Focus**: Configure optimal DNS routing policies
**Best Practices**:
• Use appropriate routing policies for service availability
• Enable proper load distribution across service instances
• Implement DNS-based service discovery

### Challenge 6: Performance Optimization - Memory Allocation
**Issue**: Container memory allocation insufficient for application needs
**Focus**: Adjust container resource limits for proper operation
**Best Practices**:
• Allocate appropriate resources based on application requirements
• Monitor resource utilization and adjust accordingly
• Prevent out-of-memory container failures

### Challenge 7: Container Configuration - Port Mapping
**Issue**: Container ports don't match load balancer expectations
**Focus**: Align container ports with load balancer expectations
**Best Practices**:
• Ensure consistent port configuration across the stack
• Match container ports with target group settings
• Implement proper container networking

### Challenge 8: Application Monitoring - Health Checks
**Issue**: No container-level health verification implemented
**Focus**: Implement container-level health verification
**Best Practices**:
• Add application health check endpoints
• Configure container health monitoring
• Enable early detection of application issues

### Challenge 9: Service Orchestration - Availability
**Issue**: Service configured with zero running instances
**Focus**: Ensure adequate service replica count for high availability
**Best Practices**:
• Configure minimum service instance count
• Implement multi-AZ deployment patterns
• Ensure service availability and fault tolerance

### Challenge 10: Deployment Strategy - Rolling Updates
**Issue**: No deployment configuration for zero-downtime updates
**Focus**: Configure proper deployment parameters for zero-downtime updates
**Best Practices**:
• Enable rolling deployment strategies
• Configure appropriate deployment percentages
• Minimize service disruption during updates

### Challenge 11: Auto Scaling - Performance Thresholds
**Issue**: Auto scaling triggers set too aggressively
**Focus**: Optimize scaling triggers for production workloads
**Best Practices**:
• Set appropriate CPU utilization thresholds
• Prevent excessive scaling activities
• Balance cost and performance considerations

### Challenge 12: Infrastructure Foundation - Access Logging
**Issue**: Load balancer access logging not configured
**Focus**: Complete load balancer observability configuration
**Best Practices**:
• Enable comprehensive access logging
• Configure log storage and retention
• Implement observability best practices

## 🏆 Success Criteria

### Evaluation Results
When all challenges are completed, `bash eval.sh` should show:
```
ACCEPTED   : 12
INCOMPLETE : 0
```

### Application Functionality
The containerized application should be accessible via the ALB DNS name and return:
```json
{
  "status": "healthy",
  "service": "webapp",
  "version": "1.0.0",
  "timestamp": "2025-09-07T10:30:00Z"
}
```

</details>

---

## 📞 Support

- **Competitors**: Use AWS documentation, ECS Console, CloudWatch logs, and systematic troubleshooting
- **Instructors**: Run `remediate.sh` to see working configuration examples
- **Issues**: Check script output for specific error messages and context

## 📄 License

This project is designed for educational purposes as part of the Ethnus AWS training program.

---

**Good luck with your container orchestration challenge! 🚀**
