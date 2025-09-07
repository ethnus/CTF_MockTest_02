#!/bin/bash

# Mock Test 02 - Container Orchestration Evaluation Script
# This script evaluates the 12 challenges and provides progress feedback

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="CTF_MockTest_02"
BAK_DIR="$HOME/.tfbak/$PROJECT_NAME"
TOTAL_CHALLENGES=12

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for resources
PREFIX=""
VPC_ID=""
ALB_ARN=""
ECS_CLUSTER=""
ECS_SERVICE=""
TARGET_GROUP_ARN=""
TASK_DEF_ARN=""
SERVICE_DISCOVERY_SERVICE=""

# Challenge results
declare -A CHALLENGE_STATUS
declare -A CHALLENGE_MESSAGES

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

print_challenge() {
    echo -e "${PURPLE}[CHALLENGE]${NC} $1"
}

# Function to restore Terraform state
restore_state() {
    if [[ -f "$BAK_DIR/terraform.tfstate" ]]; then
        print_status "Restoring Terraform state..."
        cp "$BAK_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate"
    fi
}

# Function to check if infrastructure is deployed
check_infrastructure() {
    print_status "Checking if infrastructure is deployed..."
    
    cd "$SCRIPT_DIR"
    restore_state
    
    if [[ ! -f "terraform.tfstate" ]]; then
        print_error "No Terraform state found. Please run './deploy.sh' first."
        exit 1
    fi
    
    # Get prefix from Terraform state
    PREFIX=$(terraform output -raw prefix 2>/dev/null || echo "ethnus-mocktest-02")
    
    print_success "Infrastructure state found with prefix: $PREFIX"
}

# Function to gather resource IDs and information
gather_resource_ids() {
    print_status "Gathering resource information..."
    
    # Get VPC ID
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PREFIX}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    # Get ALB ARN
    ALB_ARN=$(aws elbv2 describe-load-balancers --names "${PREFIX}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
    
    # Get ECS Cluster
    ECS_CLUSTER=$(aws ecs describe-clusters --clusters "${PREFIX}-cluster" --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")
    
    # Get ECS Service
    if [[ "$ECS_CLUSTER" != "None" ]]; then
        ECS_SERVICE=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "${PREFIX}-app-service" --query 'services[0].serviceName' --output text 2>/dev/null || echo "None")
    fi
    
    # Get Target Group ARN
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "${PREFIX}-app-tg" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
    
    # Get Task Definition ARN
    TASK_DEF_ARN=$(aws ecs describe-task-definition --task-definition "${PREFIX}-app" --query 'taskDefinition.taskDefinitionArn' --output text 2>/dev/null || echo "None")
    
    # Get Service Discovery Service
    SERVICE_DISCOVERY_SERVICE=$(aws servicediscovery list-services --query "Services[?Name=='webapp'].Id" --output text 2>/dev/null || echo "None")
    
    print_success "Resource discovery completed"
}

# Challenge 1: Security group for ECS tasks must allow traffic from ALB
check_challenge_1() {
    local challenge_num=1
    local challenge_desc="ECS Security Group - Allow ALB Traffic"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$VPC_ID" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="VPC not found"
        return
    fi
    
    # Get ECS security group
    local ecs_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-ecs-tasks-*" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    
    if [[ "$ecs_sg" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS security group not found"
        return
    fi
    
    # Get ALB security group
    local alb_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-alb-*" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    
    if [[ "$alb_sg" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ALB security group not found"
        return
    fi
    
    # Check if ECS security group allows traffic from ALB security group on port 3000
    local ingress_rule=$(aws ec2 describe-security-groups --group-ids "$ecs_sg" --query "SecurityGroups[0].IpPermissions[?FromPort==\`3000\` && ToPort==\`3000\` && UserIdGroupPairs[?GroupId==\`$alb_sg\`]]" --output text)
    
    if [[ -n "$ingress_rule" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ECS security group correctly allows ALB traffic on port 3000"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS security group must allow inbound traffic from ALB security group ($alb_sg) on port 3000"
    fi
}

# Challenge 2: ALB access logs must be enabled
check_challenge_2() {
    local challenge_num=2
    local challenge_desc="ALB Access Logs Configuration"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$ALB_ARN" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Application Load Balancer not found"
        return
    fi
    
    # Check if access logs are enabled
    local access_logs=$(aws elbv2 describe-load-balancer-attributes --load-balancer-arn "$ALB_ARN" --query "Attributes[?Key=='access_logs.s3.enabled'].Value" --output text)
    
    if [[ "$access_logs" == "true" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ALB access logs are properly enabled"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ALB access logs must be enabled. Create S3 bucket and configure access logs."
    fi
}

# Challenge 3: Target Group health check path must be correct
check_challenge_3() {
    local challenge_num=3
    local challenge_desc="Target Group Health Check Path"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$TARGET_GROUP_ARN" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Target Group not found"
        return
    fi
    
    # Check health check path
    local health_check_path=$(aws elbv2 describe-target-groups --target-group-arns "$TARGET_GROUP_ARN" --query 'TargetGroups[0].HealthCheckPath' --output text)
    
    if [[ "$health_check_path" == "/health" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Target Group health check path is correct (/health)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Target Group health check path should be '/health' (currently: $health_check_path)"
    fi
}

# Challenge 4: ECS Task Role must have Service Discovery permissions
check_challenge_4() {
    local challenge_num=4
    local challenge_desc="ECS Task Role Service Discovery Permissions"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    # Get task role name
    local task_role=$(aws iam list-roles --query "Roles[?RoleName=='${PREFIX}-ecs-task-role'].RoleName" --output text 2>/dev/null || echo "None")
    
    if [[ "$task_role" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Task Role not found"
        return
    fi
    
    # Check if role has service discovery permissions
    local policies=$(aws iam list-attached-role-policies --role-name "$task_role" --query 'AttachedPolicies[].PolicyArn' --output text)
    local inline_policies=$(aws iam list-role-policies --role-name "$task_role" --query 'PolicyNames' --output text)
    
    # Check for service discovery permissions in inline policies
    local has_sd_permissions=false
    for policy in $inline_policies; do
        local policy_doc=$(aws iam get-role-policy --role-name "$task_role" --policy-name "$policy" --query 'PolicyDocument' --output json)
        if echo "$policy_doc" | jq -e '.Statement[] | select(.Action[] | test("servicediscovery"))' > /dev/null 2>&1; then
            has_sd_permissions=true
            break
        fi
    done
    
    if [[ "$has_sd_permissions" == true ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Task Role has Service Discovery permissions"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Task Role needs servicediscovery:* permissions for service registration"
    fi
}

# Challenge 5: Service Discovery routing policy must be MULTIVALUE
check_challenge_5() {
    local challenge_num=5
    local challenge_desc="Service Discovery Routing Policy"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$SERVICE_DISCOVERY_SERVICE" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Service Discovery service not found"
        return
    fi
    
    # Get service discovery service details
    local routing_policy=$(aws servicediscovery get-service --id "$SERVICE_DISCOVERY_SERVICE" --query 'Service.DnsConfig.RoutingPolicy' --output text 2>/dev/null || echo "None")
    
    if [[ "$routing_policy" == "MULTIVALUE" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Service Discovery routing policy is correctly set to MULTIVALUE"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Service Discovery routing policy should be MULTIVALUE (currently: $routing_policy)"
    fi
}

# Challenge 6: ECS Task Definition memory must be at least 512MB
check_challenge_6() {
    local challenge_num=6
    local challenge_desc="ECS Task Definition Memory Allocation"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$TASK_DEF_ARN" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Task Definition not found"
        return
    fi
    
    # Get task definition memory
    local memory=$(aws ecs describe-task-definition --task-definition "$TASK_DEF_ARN" --query 'taskDefinition.memory' --output text)
    
    if [[ "$memory" -ge 512 ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Task Definition memory is sufficient (${memory}MB)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Task Definition memory should be at least 512MB (currently: ${memory}MB)"
    fi
}

# Challenge 7: Container port mapping must be 3000
check_challenge_7() {
    local challenge_num=7
    local challenge_desc="Container Port Mapping Configuration"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$TASK_DEF_ARN" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Task Definition not found"
        return
    fi
    
    # Get container definitions and check port mappings
    local container_port=$(aws ecs describe-task-definition --task-definition "$TASK_DEF_ARN" --query 'taskDefinition.containerDefinitions[0].portMappings[0].containerPort' --output text)
    
    if [[ "$container_port" == "3000" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Container port mapping is correct (3000)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Container port should be 3000 to match target group (currently: $container_port)"
    fi
}

# Challenge 8: Container health check must be configured
check_challenge_8() {
    local challenge_num=8
    local challenge_desc="Container Health Check Configuration"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$TASK_DEF_ARN" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Task Definition not found"
        return
    fi
    
    # Check if health check is configured
    local health_check=$(aws ecs describe-task-definition --task-definition "$TASK_DEF_ARN" --query 'taskDefinition.containerDefinitions[0].healthCheck' --output text)
    
    if [[ "$health_check" != "None" && "$health_check" != "" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Container health check is properly configured"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Container health check must be configured in task definition"
    fi
}

# Challenge 9: ECS Service desired count must be at least 2
check_challenge_9() {
    local challenge_num=9
    local challenge_desc="ECS Service Desired Count for High Availability"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$ECS_SERVICE" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service not found"
        return
    fi
    
    # Get service desired count
    local desired_count=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].desiredCount' --output text)
    
    if [[ "$desired_count" -ge 2 ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service has proper desired count for HA ($desired_count)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service desired count should be at least 2 for high availability (currently: $desired_count)"
    fi
}

# Challenge 10: ECS Service deployment configuration must be set
check_challenge_10() {
    local challenge_num=10
    local challenge_desc="ECS Service Deployment Configuration"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    if [[ "$ECS_SERVICE" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service not found"
        return
    fi
    
    # Check deployment configuration
    local max_percent=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].deploymentConfiguration.maximumPercent' --output text)
    local min_percent=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].deploymentConfiguration.minimumHealthyPercent' --output text)
    
    if [[ "$max_percent" == "200" && "$min_percent" == "100" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service deployment configuration is optimal for rolling updates"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Service needs deployment configuration: maximumPercent=200, minimumHealthyPercent=100"
    fi
}

# Challenge 11: Auto Scaling CPU threshold should be 70-80%
check_challenge_11() {
    local challenge_num=11
    local challenge_desc="Auto Scaling Policy CPU Threshold"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    # Get auto scaling policy
    local policy_arn=$(aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id "service/${ECS_CLUSTER}/${ECS_SERVICE}" --query 'ScalingPolicies[0].PolicyARN' --output text 2>/dev/null || echo "None")
    
    if [[ "$policy_arn" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Auto Scaling policy not found"
        return
    fi
    
    # Get target value from policy
    local target_value=$(aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id "service/${ECS_CLUSTER}/${ECS_SERVICE}" --query 'ScalingPolicies[0].TargetTrackingScalingPolicyConfiguration.TargetValue' --output text)
    
    if [[ $(echo "$target_value >= 70.0" | bc -l) == 1 && $(echo "$target_value <= 80.0" | bc -l) == 1 ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="Auto Scaling CPU threshold is properly configured ($target_value%)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="Auto Scaling CPU threshold should be 70-80% for production (currently: $target_value%)"
    fi
}

# Challenge 12: ECS Security Group must have proper tags
check_challenge_12() {
    local challenge_num=12
    local challenge_desc="ECS Security Group Tagging"
    
    print_challenge "Challenge $challenge_num: $challenge_desc"
    
    # Get ECS security group
    local ecs_sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PREFIX}-ecs-tasks-*" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    
    if [[ "$ecs_sg" == "None" ]]; then
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS security group not found"
        return
    fi
    
    # Check if security group has required tags
    local name_tag=$(aws ec2 describe-security-groups --group-ids "$ecs_sg" --query "SecurityGroups[0].Tags[?Key=='Name'].Value" --output text)
    local project_tag=$(aws ec2 describe-security-groups --group-ids "$ecs_sg" --query "SecurityGroups[0].Tags[?Key=='Project'].Value" --output text)
    
    if [[ -n "$name_tag" && -n "$project_tag" ]]; then
        CHALLENGE_STATUS[$challenge_num]="ACCEPTED"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Security Group has proper tags (Name: $name_tag)"
    else
        CHALLENGE_STATUS[$challenge_num]="INCOMPLETE"
        CHALLENGE_MESSAGES[$challenge_num]="ECS Security Group must have proper tags (Name, Project, Environment)"
    fi
}

# Function to run all challenges
run_all_challenges() {
    print_status "Running all $TOTAL_CHALLENGES challenges..."
    echo
    
    check_challenge_1
    check_challenge_2
    check_challenge_3
    check_challenge_4
    check_challenge_5
    check_challenge_6
    check_challenge_7
    check_challenge_8
    check_challenge_9
    check_challenge_10
    check_challenge_11
    check_challenge_12
    
    echo
}

# Function to display results table
display_results() {
    print_status "=== MOCK TEST 02 - CHALLENGE RESULTS ==="
    echo
    
    printf "%-5s %-50s %-12s %-60s\n" "ID" "CHALLENGE" "STATUS" "MESSAGE"
    printf "%-5s %-50s %-12s %-60s\n" "---" "------------------------------------------------" "----------" "----------------------------------------------------------"
    
    local accepted_count=0
    
    for i in {1..12}; do
        local status="${CHALLENGE_STATUS[$i]:-INCOMPLETE}"
        local message="${CHALLENGE_MESSAGES[$i]:-No message}"
        
        # Truncate message if too long
        if [[ ${#message} -gt 58 ]]; then
            message="${message:0:55}..."
        fi
        
        # Color code the status
        local colored_status=""
        if [[ "$status" == "ACCEPTED" ]]; then
            colored_status="${GREEN}ACCEPTED${NC}"
            ((accepted_count++))
        else
            colored_status="${RED}INCOMPLETE${NC}"
        fi
        
        printf "%-5s %-50s %-22s %-60s\n" "$i" "$(get_challenge_title $i)" "$colored_status" "$message"
    done
    
    echo
    print_status "=== PROGRESS SUMMARY ==="
    echo "Total Challenges: $TOTAL_CHALLENGES"
    echo "Completed: $accepted_count"
    echo "Remaining: $((TOTAL_CHALLENGES - accepted_count))"
    
    if [[ $accepted_count -eq $TOTAL_CHALLENGES ]]; then
        echo
        print_success "🎉 CONGRATULATIONS! 🎉"
        print_success "All challenges completed successfully!"
        print_success "You have mastered Container Orchestration and Service Discovery!"
    else
        echo
        print_warning "Keep working on the remaining challenges!"
        print_warning "Use AWS Console/CLI to investigate and fix the issues."
    fi
    
    echo
}

# Function to get challenge titles
get_challenge_title() {
    case $1 in
        1) echo "ECS Security Group - Allow ALB Traffic" ;;
        2) echo "ALB Access Logs Configuration" ;;
        3) echo "Target Group Health Check Path" ;;
        4) echo "ECS Task Role Service Discovery Permissions" ;;
        5) echo "Service Discovery Routing Policy" ;;
        6) echo "ECS Task Definition Memory Allocation" ;;
        7) echo "Container Port Mapping Configuration" ;;
        8) echo "Container Health Check Configuration" ;;
        9) echo "ECS Service Desired Count for High Availability" ;;
        10) echo "ECS Service Deployment Configuration" ;;
        11) echo "Auto Scaling Policy CPU Threshold" ;;
        12) echo "ECS Security Group Tagging" ;;
        *) echo "Unknown Challenge" ;;
    esac
}

# Function to show help
show_help() {
    echo "Mock Test 02 - Container Orchestration Evaluation"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo
    echo "This script evaluates 12 challenges focused on:"
    echo "• ECS Fargate and container orchestration"
    echo "• Application Load Balancer configuration"
    echo "• Service Discovery and networking"
    echo "• Auto Scaling and health monitoring"
    echo "• Security groups and IAM permissions"
    echo
}

# Main execution
main() {
    echo "=================================================="
    echo "  Ethnus AWS Training - Mock Test 02 Evaluation"
    echo "  Focus: Container Orchestration & Service Discovery"
    echo "=================================================="
    echo
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if script is being run from the correct directory
    if [[ ! -f "$SCRIPT_DIR/main.tf" ]]; then
        print_error "main.tf not found! Please run this script from the scripts/ directory"
        exit 1
    fi
    
    # Check infrastructure and gather resources
    check_infrastructure
    gather_resource_ids
    
    # Run all challenges
    run_all_challenges
    
    # Display results
    display_results
}

# Run main function
main "$@"
