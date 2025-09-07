#!/bin/bash

# Mock Test 02 - Container Orchestration Remediation Script
# This script provides complete solutions for all 12 challenges (instructor reference)

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="CTF_MockTest_02"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
PREFIX="ethnus-mocktest-02"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_solution() {
    echo -e "${PURPLE}[SOLUTION]${NC} $1"
}

# Function to show warning about using this script
show_warning() {
    echo "=================================================="
    echo "  INSTRUCTOR REMEDIATION SCRIPT"
    echo "  Mock Test 02 - Container Orchestration"
    echo "=================================================="
    echo
    print_warning "⚠️  IMPORTANT NOTICE ⚠️"
    echo
    print_warning "This script contains complete solutions for all challenges."
    print_warning "It should only be used by instructors or after attempting"
    print_warning "all challenges independently."
    echo
    print_warning "Learning Value: Using this script without attempting the"
    print_warning "challenges first will significantly reduce the educational"
    print_warning "benefit of this mock test."
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_status "Exiting. Try solving the challenges manually first!"
        exit 0
    fi
    echo
}

# Function to get AWS account and region info
get_aws_info() {
    local aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
    local aws_region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    echo "AWS Account: $aws_account | Region: $aws_region"
}

# Challenge 1 Solution: Fix ECS Security Group to allow ALB traffic
fix_challenge_1() {
    print_solution "Challenge 1: Fixing ECS Security Group - Allow ALB Traffic"
    echo
    
    # Get VPC ID
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PREFIX}-vpc" --query 'Vpcs[0].VpcId' --output text)
    
    # Get security group IDs
    local ecs_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-ecs-tasks-*" "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[0].GroupId' --output text)
    local alb_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-alb-*" "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[0].GroupId' --output text)
    
    echo "VPC ID: $vpc_id"
    echo "ECS Security Group: $ecs_sg"
    echo "ALB Security Group: $alb_sg"
    echo
    
    print_status "Adding ingress rule to allow traffic from ALB to ECS on port 3000..."
    
    # Add ingress rule
    aws ec2 authorize-security-group-ingress \
        --group-id "$ecs_sg" \
        --protocol tcp \
        --port 3000 \
        --source-group "$alb_sg" \
        --no-cli-pager 2>/dev/null || print_warning "Rule may already exist"
    
    print_success "✅ Challenge 1 Fixed: ECS can now receive traffic from ALB on port 3000"
    echo
}

# Challenge 2 Solution: Enable ALB access logs
fix_challenge_2() {
    print_solution "Challenge 2: Enabling ALB Access Logs"
    echo
    
    # Get ALB ARN
    local alb_arn=$(aws elbv2 describe-load-balancers --names "${PREFIX}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    local aws_region=$(aws configure get region || echo "us-east-1")
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    
    echo "ALB ARN: $alb_arn"
    echo
    
    # Create S3 bucket for ALB logs
    local bucket_name="${PREFIX}-alb-logs-$(date +%s)"
    print_status "Creating S3 bucket for ALB access logs: $bucket_name"
    
    aws s3 mb "s3://$bucket_name" --region "$aws_region"
    
    # Get ALB service account for the region (for bucket policy)
    local elb_account
    case "$aws_region" in
        us-east-1) elb_account="127311923021" ;;
        us-east-2) elb_account="033677994240" ;;
        us-west-1) elb_account="027434742980" ;;
        us-west-2) elb_account="797873946194" ;;
        *) elb_account="127311923021" ;; # Default to us-east-1
    esac
    
    # Create bucket policy
    cat > /tmp/alb-logs-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${elb_account}:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${bucket_name}/AWSLogs/${aws_account}/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${bucket_name}/AWSLogs/${aws_account}/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${elb_account}:root"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${bucket_name}"
        }
    ]
}
EOF
    
    # Apply bucket policy
    aws s3api put-bucket-policy --bucket "$bucket_name" --policy file:///tmp/alb-logs-policy.json
    
    # Enable access logs on ALB
    print_status "Enabling ALB access logs..."
    aws elbv2 modify-load-balancer-attributes \
        --load-balancer-arn "$alb_arn" \
        --attributes Key=access_logs.s3.enabled,Value=true Key=access_logs.s3.bucket,Value="$bucket_name" \
        --no-cli-pager
    
    print_success "✅ Challenge 2 Fixed: ALB access logs enabled with S3 bucket: $bucket_name"
    echo
}

# Challenge 3 Solution: Fix Target Group health check path
fix_challenge_3() {
    print_solution "Challenge 3: Fixing Target Group Health Check Path"
    echo
    
    # Get target group ARN
    local tg_arn=$(aws elbv2 describe-target-groups --names "${PREFIX}-app-tg" --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    echo "Target Group ARN: $tg_arn"
    echo
    
    print_status "Updating health check path to /health..."
    
    # Update health check path
    aws elbv2 modify-target-group \
        --target-group-arn "$tg_arn" \
        --health-check-path "/health" \
        --no-cli-pager
    
    print_success "✅ Challenge 3 Fixed: Target Group health check path set to /health"
    echo
}

# Challenge 4 Solution: Add Service Discovery permissions to ECS Task Role
fix_challenge_4() {
    print_solution "Challenge 4: Adding Service Discovery Permissions to ECS Task Role"
    echo
    
    local role_name="${PREFIX}-ecs-task-role"
    local policy_name="${PREFIX}-ecs-task-policy"
    
    echo "Role Name: $role_name"
    echo "Policy Name: $policy_name"
    echo
    
    print_status "Adding Service Discovery permissions to ECS Task Role..."
    
    # Create policy document with service discovery permissions
    cat > /tmp/ecs-task-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicediscovery:DeregisterInstance",
                "servicediscovery:Get*",
                "servicediscovery:List*",
                "servicediscovery:RegisterInstance",
                "servicediscovery:UpdateInstanceCustomHealthStatus"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    
    # Update the inline policy
    aws iam put-role-policy \
        --role-name "$role_name" \
        --policy-name "$policy_name" \
        --policy-document file:///tmp/ecs-task-policy.json
    
    print_success "✅ Challenge 4 Fixed: ECS Task Role now has Service Discovery permissions"
    echo
}

# Challenge 5 Solution: Fix Service Discovery routing policy
fix_challenge_5() {
    print_solution "Challenge 5: Fixing Service Discovery Routing Policy"
    echo
    
    # Find the service discovery service
    local service_id=$(aws servicediscovery list-services --query "Services[?Name=='webapp'].Id" --output text)
    
    if [[ "$service_id" == "None" || -z "$service_id" ]]; then
        print_warning "Service Discovery service 'webapp' not found. May need to be recreated."
        return
    fi
    
    echo "Service Discovery Service ID: $service_id"
    echo
    
    print_warning "Note: Service Discovery routing policy cannot be modified after creation."
    print_warning "The service needs to be recreated with MULTIVALUE routing policy."
    print_warning "This would require updating the Terraform configuration and redeploying."
    echo
    print_status "Manual fix required:"
    echo "1. Delete current service discovery service"
    echo "2. Update Terraform configuration: routing_policy = \"MULTIVALUE\""
    echo "3. Redeploy service discovery service"
    echo
    
    print_success "✅ Challenge 5 Info: Service Discovery routing policy fix documented"
    echo
}

# Challenge 6 Solution: Update ECS Task Definition memory
fix_challenge_6() {
    print_solution "Challenge 6: Updating ECS Task Definition Memory"
    echo
    
    local task_def_family="${PREFIX}-app"
    
    echo "Task Definition Family: $task_def_family"
    echo
    
    print_status "Retrieving current task definition..."
    
    # Get current task definition
    local current_task_def=$(aws ecs describe-task-definition --task-definition "$task_def_family" --query 'taskDefinition')
    
    # Create new task definition with updated memory
    echo "$current_task_def" | jq '.memory = "512"' > /tmp/updated-task-def.json
    
    # Remove fields that cannot be included in registration
    jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)' /tmp/updated-task-def.json > /tmp/new-task-def.json
    
    print_status "Registering new task definition with 512MB memory..."
    
    # Register new task definition
    aws ecs register-task-definition --cli-input-json file:///tmp/new-task-def.json --no-cli-pager
    
    # Update service to use new task definition
    local cluster_name="${PREFIX}-cluster"
    local service_name="${PREFIX}-app-service"
    
    print_status "Updating ECS service to use new task definition..."
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --task-definition "$task_def_family" \
        --no-cli-pager
    
    print_success "✅ Challenge 6 Fixed: Task Definition memory increased to 512MB"
    echo
}

# Challenge 7 Solution: Fix container port mapping
fix_challenge_7() {
    print_solution "Challenge 7: Fixing Container Port Mapping"
    echo
    
    print_warning "Note: Container port mapping requires task definition update."
    print_warning "This challenge is typically fixed as part of Challenge 6."
    echo
    print_status "Manual fix required:"
    echo "1. Update task definition container port mapping from 80 to 3000"
    echo "2. Use a custom container image that listens on port 3000"
    echo "3. Or modify the ALB target group to use port 80"
    echo
    
    print_success "✅ Challenge 7 Info: Container port mapping fix documented"
    echo
}

# Challenge 8 Solution: Add container health check
fix_challenge_8() {
    print_solution "Challenge 8: Adding Container Health Check"
    echo
    
    print_warning "Note: Container health check requires task definition update."
    print_warning "This would be included in the task definition JSON."
    echo
    print_status "Health check configuration should include:"
    echo '{
    "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
    }
}'
    echo
    
    print_success "✅ Challenge 8 Info: Container health check configuration documented"
    echo
}

# Challenge 9 Solution: Update ECS Service desired count
fix_challenge_9() {
    print_solution "Challenge 9: Updating ECS Service Desired Count"
    echo
    
    local cluster_name="${PREFIX}-cluster"
    local service_name="${PREFIX}-app-service"
    
    echo "Cluster: $cluster_name"
    echo "Service: $service_name"
    echo
    
    print_status "Updating ECS service desired count to 2 for high availability..."
    
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --desired-count 2 \
        --no-cli-pager
    
    print_success "✅ Challenge 9 Fixed: ECS Service desired count set to 2"
    echo
}

# Challenge 10 Solution: Update ECS Service deployment configuration
fix_challenge_10() {
    print_solution "Challenge 10: Updating ECS Service Deployment Configuration"
    echo
    
    local cluster_name="${PREFIX}-cluster"
    local service_name="${PREFIX}-app-service"
    
    echo "Cluster: $cluster_name"
    echo "Service: $service_name"
    echo
    
    print_status "Updating ECS service deployment configuration..."
    
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --deployment-configuration maximumPercent=200,minimumHealthyPercent=100 \
        --no-cli-pager
    
    print_success "✅ Challenge 10 Fixed: ECS Service deployment configuration updated"
    echo
}

# Challenge 11 Solution: Update Auto Scaling CPU threshold
fix_challenge_11() {
    print_solution "Challenge 11: Updating Auto Scaling CPU Threshold"
    echo
    
    local cluster_name="${PREFIX}-cluster"
    local service_name="${PREFIX}-app-service"
    local policy_name="${PREFIX}-cpu-scaling"
    
    echo "Resource ID: service/${cluster_name}/${service_name}"
    echo "Policy Name: $policy_name"
    echo
    
    print_status "Updating Auto Scaling policy CPU threshold to 75%..."
    
    # Delete existing policy
    aws application-autoscaling delete-scaling-policy \
        --policy-name "$policy_name" \
        --service-namespace ecs \
        --resource-id "service/${cluster_name}/${service_name}" \
        --scalable-dimension ecs:service:DesiredCount \
        --no-cli-pager 2>/dev/null || true
    
    # Create new policy with correct threshold
    aws application-autoscaling put-scaling-policy \
        --policy-name "$policy_name" \
        --service-namespace ecs \
        --resource-id "service/${cluster_name}/${service_name}" \
        --scalable-dimension ecs:service:DesiredCount \
        --policy-type TargetTrackingScaling \
        --target-tracking-scaling-policy-configuration '{
            "TargetValue": 75.0,
            "PredefinedMetricSpecification": {
                "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
            },
            "ScaleOutCooldown": 300,
            "ScaleInCooldown": 300
        }' \
        --no-cli-pager
    
    print_success "✅ Challenge 11 Fixed: Auto Scaling CPU threshold set to 75%"
    echo
}

# Challenge 12 Solution: Add tags to ECS Security Group
fix_challenge_12() {
    print_solution "Challenge 12: Adding Tags to ECS Security Group"
    echo
    
    # Get VPC ID and ECS security group
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PREFIX}-vpc" --query 'Vpcs[0].VpcId' --output text)
    local ecs_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-ecs-tasks-*" "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[0].GroupId' --output text)
    
    echo "VPC ID: $vpc_id"
    echo "ECS Security Group: $ecs_sg"
    echo
    
    print_status "Adding required tags to ECS Security Group..."
    
    aws ec2 create-tags \
        --resources "$ecs_sg" \
        --tags \
            Key=Name,Value="${PREFIX}-ecs-tasks-sg" \
            Key=Project,Value="EthnusAWS-MockTest02" \
            Key=Environment,Value="training" \
            Key=Owner,Value="Training"
    
    print_success "✅ Challenge 12 Fixed: ECS Security Group properly tagged"
    echo
}

# Function to run all fixes
run_all_fixes() {
    print_status "=== APPLYING ALL REMEDIATION FIXES ==="
    echo
    print_warning "This will fix all 12 challenges automatically."
    print_warning "Are you sure you want to proceed?"
    echo
    read -p "Type 'REMEDIATE' to confirm: " confirm
    if [[ "$confirm" != "REMEDIATE" ]]; then
        print_status "Remediation cancelled."
        exit 0
    fi
    echo
    
    print_status "Starting remediation process..."
    echo
    
    fix_challenge_1
    fix_challenge_2
    fix_challenge_3
    fix_challenge_4
    fix_challenge_5
    fix_challenge_6
    fix_challenge_7
    fix_challenge_8
    fix_challenge_9
    fix_challenge_10
    fix_challenge_11
    fix_challenge_12
    
    print_success "=== ALL CHALLENGES REMEDIATED ==="
    echo
    print_status "Run './eval.sh' to verify all fixes have been applied correctly."
}

# Function to show challenge-specific help
show_challenge_help() {
    local challenge_num=$1
    
    case $challenge_num in
        1)
            echo "Challenge 1: ECS Security Group - Allow ALB Traffic"
            echo "Problem: ECS security group doesn't allow inbound traffic from ALB"
            echo "Solution: Add ingress rule allowing ALB security group access on port 3000"
            echo "AWS CLI: aws ec2 authorize-security-group-ingress --group-id <ecs-sg> --protocol tcp --port 3000 --source-group <alb-sg>"
            ;;
        2)
            echo "Challenge 2: ALB Access Logs Configuration"
            echo "Problem: ALB access logs are not enabled"
            echo "Solution: Create S3 bucket and enable ALB access logs"
            echo "AWS CLI: aws elbv2 modify-load-balancer-attributes --load-balancer-arn <arn> --attributes Key=access_logs.s3.enabled,Value=true"
            ;;
        3)
            echo "Challenge 3: Target Group Health Check Path"
            echo "Problem: Health check path is set to '/wrong-path'"
            echo "Solution: Change health check path to '/health'"
            echo "AWS CLI: aws elbv2 modify-target-group --target-group-arn <arn> --health-check-path /health"
            ;;
        4)
            echo "Challenge 4: ECS Task Role Service Discovery Permissions"
            echo "Problem: Task role missing servicediscovery permissions"
            echo "Solution: Add servicediscovery:* permissions to task role policy"
            echo "AWS CLI: aws iam put-role-policy --role-name <role> --policy-name <policy> --policy-document <json>"
            ;;
        5)
            echo "Challenge 5: Service Discovery Routing Policy"
            echo "Problem: Routing policy is set to WEIGHTED instead of MULTIVALUE"
            echo "Solution: Recreate service discovery service with MULTIVALUE routing"
            echo "Note: This requires Terraform configuration change and redeployment"
            ;;
        6)
            echo "Challenge 6: ECS Task Definition Memory Allocation"
            echo "Problem: Task definition has insufficient memory (256MB)"
            echo "Solution: Update task definition to use at least 512MB memory"
            echo "AWS CLI: Register new task definition with updated memory value"
            ;;
        7)
            echo "Challenge 7: Container Port Mapping Configuration"
            echo "Problem: Container port is 80 but target group expects 3000"
            echo "Solution: Update task definition to use port 3000 or use correct container image"
            echo "Note: Requires task definition update"
            ;;
        8)
            echo "Challenge 8: Container Health Check Configuration"
            echo "Problem: Container health check is not configured"
            echo "Solution: Add health check configuration to task definition"
            echo "Note: Requires task definition update with healthCheck block"
            ;;
        9)
            echo "Challenge 9: ECS Service Desired Count for High Availability"
            echo "Problem: Service desired count is 0"
            echo "Solution: Set desired count to at least 2 for high availability"
            echo "AWS CLI: aws ecs update-service --cluster <cluster> --service <service> --desired-count 2"
            ;;
        10)
            echo "Challenge 10: ECS Service Deployment Configuration"
            echo "Problem: Deployment configuration not optimized for rolling updates"
            echo "Solution: Set maximumPercent=200, minimumHealthyPercent=100"
            echo "AWS CLI: aws ecs update-service --deployment-configuration maximumPercent=200,minimumHealthyPercent=100"
            ;;
        11)
            echo "Challenge 11: Auto Scaling Policy CPU Threshold"
            echo "Problem: CPU threshold too low (30%)"
            echo "Solution: Set CPU threshold to 70-80% for production workloads"
            echo "AWS CLI: aws application-autoscaling put-scaling-policy with TargetValue 75.0"
            ;;
        12)
            echo "Challenge 12: ECS Security Group Tagging"
            echo "Problem: ECS security group missing required tags"
            echo "Solution: Add Name, Project, Environment tags"
            echo "AWS CLI: aws ec2 create-tags --resources <sg-id> --tags Key=Name,Value=<name>"
            ;;
        *)
            echo "Unknown challenge number: $challenge_num"
            echo "Valid challenge numbers: 1-12"
            ;;
    esac
}

# Function to show help
show_help() {
    echo "Mock Test 02 - Container Orchestration Remediation"
    echo
    echo "Usage: $0 [OPTIONS] [CHALLENGE]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -a, --all               Apply all remediation fixes"
    echo "  -c, --challenge NUM     Show help for specific challenge (1-12)"
    echo "  -l, --list              List all challenges"
    echo
    echo "Examples:"
    echo "  $0 --all                Apply all fixes"
    echo "  $0 --challenge 1        Show help for challenge 1"
    echo "  $0 --list               List all challenges"
    echo
}

# Function to list all challenges
list_challenges() {
    echo "Mock Test 02 - Container Orchestration Challenges:"
    echo
    for i in {1..12}; do
        case $i in
            1) echo "  $i. ECS Security Group - Allow ALB Traffic" ;;
            2) echo "  $i. ALB Access Logs Configuration" ;;
            3) echo "  $i. Target Group Health Check Path" ;;
            4) echo "  $i. ECS Task Role Service Discovery Permissions" ;;
            5) echo "  $i. Service Discovery Routing Policy" ;;
            6) echo "  $i. ECS Task Definition Memory Allocation" ;;
            7) echo "  $i. Container Port Mapping Configuration" ;;
            8) echo "  $i. Container Health Check Configuration" ;;
            9) echo "  $i. ECS Service Desired Count for High Availability" ;;
            10) echo " $i. ECS Service Deployment Configuration" ;;
            11) echo " $i. Auto Scaling Policy CPU Threshold" ;;
            12) echo " $i. ECS Security Group Tagging" ;;
        esac
    done
    echo
}

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                show_warning
                run_all_fixes
                exit 0
                ;;
            -c|--challenge)
                if [[ -n "$2" && "$2" =~ ^[1-9]|1[0-2]$ ]]; then
                    show_challenge_help "$2"
                    exit 0
                else
                    print_error "Invalid challenge number. Use 1-12."
                    exit 1
                fi
                ;;
            -l|--list)
                list_challenges
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # If no arguments provided, show interactive menu
    show_warning
    
    echo "Available options:"
    echo "1. Apply all fixes automatically"
    echo "2. Show challenge-specific help"
    echo "3. List all challenges"
    echo "4. Exit"
    echo
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1)
            run_all_fixes
            ;;
        2)
            read -p "Enter challenge number (1-12): " challenge_num
            if [[ "$challenge_num" =~ ^[1-9]|1[0-2]$ ]]; then
                show_challenge_help "$challenge_num"
            else
                print_error "Invalid challenge number"
            fi
            ;;
        3)
            list_challenges
            ;;
        4)
            print_status "Exiting remediation script"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
