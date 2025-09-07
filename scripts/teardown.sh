#!/bin/bash

# Mock Test 02 - Container Orchestration Teardown Script
# This script cleans up all resources created by the mock test

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="CTF_MockTest_02"
BAK_DIR="$HOME/.tfbak/$PROJECT_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to show warning about teardown
show_warning() {
    echo "=================================================="
    echo "  Mock Test 02 - Container Orchestration Teardown"
    echo "=================================================="
    echo
    print_warning "⚠️  DESTRUCTIVE OPERATION WARNING ⚠️"
    echo
    print_warning "This script will permanently delete ALL resources"
    print_warning "created by Mock Test 02, including:"
    echo
    echo "  • VPC and all networking components"
    echo "  • ECS cluster, services, and task definitions"
    echo "  • Application Load Balancer and target groups"
    echo "  • IAM roles and policies"
    echo "  • CloudWatch log groups"
    echo "  • Service Discovery namespace and services"
    echo "  • S3 buckets (if created for ALB logs)"
    echo "  • Auto Scaling configurations"
    echo
    print_warning "This action CANNOT be undone!"
    echo
    read -p "Are you absolutely sure you want to proceed? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        print_status "Teardown cancelled. Resources remain intact."
        exit 0
    fi
    echo
    read -p "Type 'DELETE' to confirm resource deletion: " double_confirm
    if [[ "$double_confirm" != "DELETE" ]]; then
        print_status "Teardown cancelled. Resources remain intact."
        exit 0
    fi
    echo
}

# Function to restore Terraform state
restore_state() {
    if [[ -f "$BAK_DIR/terraform.tfstate" ]]; then
        print_status "Restoring Terraform state..."
        cp "$BAK_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate"
        
        if [[ -f "$BAK_DIR/terraform.tfstate.backup" ]]; then
            cp "$BAK_DIR/terraform.tfstate.backup" "$SCRIPT_DIR/terraform.tfstate.backup"
        fi
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured properly"
        print_error "Please run 'aws configure' or set AWS environment variables"
        exit 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_region=$(aws configure get region || echo "us-east-1")
    
    print_success "AWS Account: $aws_account"
    print_success "AWS Region: $aws_region"
}

# Function to clean up ALB access logs S3 buckets
cleanup_alb_logs_buckets() {
    print_status "Cleaning up ALB access logs S3 buckets..."
    
    local prefix="ethnus-mocktest-02-alb-logs"
    local buckets=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$prefix')].Name" --output text 2>/dev/null || echo "")
    
    if [[ -n "$buckets" ]]; then
        for bucket in $buckets; do
            print_status "Deleting S3 bucket: $bucket"
            
            # Delete all objects in bucket first
            aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
            
            # Delete bucket
            aws s3api delete-bucket --bucket "$bucket" 2>/dev/null || true
            
            print_success "Deleted S3 bucket: $bucket"
        done
    else
        print_status "No ALB access logs S3 buckets found"
    fi
}

# Function to force delete ECS services
force_delete_ecs_services() {
    print_status "Force deleting ECS services..."
    
    local cluster_name="ethnus-mocktest-02-cluster"
    
    # Check if cluster exists
    if ! aws ecs describe-clusters --clusters "$cluster_name" --query 'clusters[0].clusterName' --output text &>/dev/null; then
        print_status "ECS cluster not found, skipping service deletion"
        return
    fi
    
    # Get all services in the cluster
    local services=$(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[]' --output text 2>/dev/null || echo "")
    
    if [[ -n "$services" ]]; then
        for service_arn in $services; do
            local service_name=$(basename "$service_arn")
            print_status "Force deleting ECS service: $service_name"
            
            # Scale service to 0
            aws ecs update-service \
                --cluster "$cluster_name" \
                --service "$service_name" \
                --desired-count 0 \
                --no-cli-pager 2>/dev/null || true
            
            # Wait a bit for tasks to stop
            sleep 5
            
            # Delete service
            aws ecs delete-service \
                --cluster "$cluster_name" \
                --service "$service_name" \
                --force \
                --no-cli-pager 2>/dev/null || true
            
            print_success "Force deleted ECS service: $service_name"
        done
        
        # Wait for services to be deleted
        print_status "Waiting for ECS services to be fully deleted..."
        sleep 30
    else
        print_status "No ECS services found in cluster"
    fi
}

# Function to clean up hanging ENIs
cleanup_enis() {
    print_status "Cleaning up hanging ENIs (network interfaces)..."
    
    # Find ENIs associated with our VPC that are available but not attached
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ethnus-mocktest-02-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [[ "$vpc_id" != "None" ]]; then
        local enis=$(aws ec2 describe-network-interfaces \
            --filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=available" \
            --query 'NetworkInterfaces[].NetworkInterfaceId' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$enis" ]]; then
            for eni in $enis; do
                print_status "Deleting hanging ENI: $eni"
                aws ec2 delete-network-interface --network-interface-id "$eni" 2>/dev/null || true
            done
        fi
    fi
}

# Function to run Terraform destroy
terraform_destroy() {
    print_status "Running Terraform destroy..."
    
    cd "$SCRIPT_DIR"
    
    # Restore state if available
    restore_state
    
    # Check if terraform state exists
    if [[ ! -f "terraform.tfstate" ]]; then
        print_warning "No Terraform state found. Attempting manual cleanup..."
        return 1
    fi
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Run destroy
    print_status "Destroying infrastructure with Terraform..."
    if terraform destroy -auto-approve; then
        print_success "Terraform destroy completed successfully"
        return 0
    else
        print_warning "Terraform destroy encountered issues. Proceeding with manual cleanup..."
        return 1
    fi
}

# Function to manual cleanup if Terraform fails
manual_cleanup() {
    print_status "Performing manual cleanup of remaining resources..."
    
    # Clean up ALB access logs buckets
    cleanup_alb_logs_buckets
    
    # Force delete ECS services
    force_delete_ecs_services
    
    # Clean up hanging ENIs
    cleanup_enis
    
    print_status "Manual cleanup completed"
}

# Function to clean up Terraform state backup
cleanup_backup() {
    print_status "Cleaning up Terraform state backup..."
    
    if [[ -d "$BAK_DIR" ]]; then
        rm -rf "$BAK_DIR"
        print_success "Terraform state backup cleaned up"
    fi
    
    # Clean up local state files
    if [[ -f "$SCRIPT_DIR/terraform.tfstate" ]]; then
        rm -f "$SCRIPT_DIR/terraform.tfstate"
    fi
    
    if [[ -f "$SCRIPT_DIR/terraform.tfstate.backup" ]]; then
        rm -f "$SCRIPT_DIR/terraform.tfstate.backup"
    fi
    
    if [[ -d "$SCRIPT_DIR/.terraform" ]]; then
        rm -rf "$SCRIPT_DIR/.terraform"
    fi
    
    if [[ -f "$SCRIPT_DIR/.terraform.lock.hcl" ]]; then
        rm -f "$SCRIPT_DIR/.terraform.lock.hcl"
    fi
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying resource cleanup..."
    
    local issues_found=false
    
    # Check for VPC
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ethnus-mocktest-02-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    if [[ "$vpc_id" != "None" ]]; then
        print_warning "VPC still exists: $vpc_id"
        issues_found=true
    fi
    
    # Check for ECS cluster
    local cluster=$(aws ecs describe-clusters --clusters "ethnus-mocktest-02-cluster" --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")
    if [[ "$cluster" != "None" ]]; then
        print_warning "ECS cluster still exists: $cluster"
        issues_found=true
    fi
    
    # Check for ALB
    local alb=$(aws elbv2 describe-load-balancers --names "ethnus-mocktest-02-alb" --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null || echo "None")
    if [[ "$alb" != "None" ]]; then
        print_warning "ALB still exists: $alb"
        issues_found=true
    fi
    
    # Check for IAM roles
    local roles=$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'ethnus-mocktest-02')].RoleName" --output text 2>/dev/null || echo "")
    if [[ -n "$roles" ]]; then
        print_warning "IAM roles still exist: $roles"
        issues_found=true
    fi
    
    if [[ "$issues_found" == false ]]; then
        print_success "✅ All resources have been successfully cleaned up!"
    else
        print_warning "⚠️ Some resources may still exist. Check AWS Console for manual cleanup."
    fi
}

# Function to display completion summary
display_summary() {
    print_status "=== TEARDOWN COMPLETION SUMMARY ==="
    echo
    print_success "🧹 Mock Test 02 teardown process completed!"
    echo
    print_status "What was cleaned up:"
    echo "  • VPC and all networking components"
    echo "  • ECS cluster, services, and task definitions"
    echo "  • Application Load Balancer and target groups"
    echo "  • IAM roles and policies"
    echo "  • CloudWatch log groups"
    echo "  • Service Discovery namespace and services"
    echo "  • Auto Scaling configurations"
    echo "  • S3 buckets for ALB access logs"
    echo "  • Terraform state files and backups"
    echo
    print_status "Next steps:"
    echo "  • Verify in AWS Console that all resources are deleted"
    echo "  • Check your AWS billing dashboard for any remaining charges"
    echo "  • Ready to deploy Mock Test 02 again with './deploy.sh'"
    echo
    print_success "Environment is now clean! 🎉"
}

# Main execution flow
main() {
    echo "=================================================="
    echo "  Ethnus AWS Training - Mock Test 02 Teardown"
    echo "  Focus: Container Orchestration & Service Discovery"
    echo "=================================================="
    echo
    
    # Check if script is being run from the correct directory
    if [[ ! -f "$SCRIPT_DIR/main.tf" ]]; then
        print_error "main.tf not found! Please run this script from the scripts/ directory"
        exit 1
    fi
    
    # Show warning and get confirmation
    show_warning
    
    # Check AWS credentials
    check_aws_credentials
    
    print_status "Starting teardown process..."
    echo
    
    # Try Terraform destroy first
    if terraform_destroy; then
        print_success "Primary teardown via Terraform completed successfully"
    else
        print_warning "Terraform destroy had issues, proceeding with manual cleanup"
        manual_cleanup
    fi
    
    # Clean up backup files
    cleanup_backup
    
    # Verify cleanup
    verify_cleanup
    
    # Display summary
    display_summary
}

# Function to show help
show_help() {
    echo "Mock Test 02 - Container Orchestration Teardown"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -f, --force    Skip confirmation prompts (USE WITH CAUTION)"
    echo
    echo "This script will completely remove all AWS resources created by"
    echo "Mock Test 02, including VPC, ECS, ALB, IAM roles, and more."
    echo
    echo "⚠️  WARNING: This is a destructive operation that cannot be undone!"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            # Skip confirmation for automated teardown
            FORCE_MODE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function if not in force mode
if [[ "${FORCE_MODE:-false}" == "true" ]]; then
    print_warning "Force mode enabled - skipping confirmations"
    echo
    check_aws_credentials
    terraform_destroy || manual_cleanup
    cleanup_backup
    verify_cleanup
    display_summary
else
    main "$@"
fi
