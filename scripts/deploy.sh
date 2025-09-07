#!/bin/bash

# Mock Test 02 - Container Orchestration Deployment Script
# This script deploys the intentionally misconfigured infrastructure for learning

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

# Function to check and install required tools
install_tools() {
    print_status "Checking and installing required tools..."
    
    # Check if running in CloudShell
    if [[ "$CLOUDSHELL" == "true" ]]; then
        print_status "Running in AWS CloudShell"
    else
        print_status "Running in local environment"
    fi
    
    # Install Terraform if not present
    if ! command -v terraform &> /dev/null; then
        print_status "Installing Terraform..."
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install terraform -y
    else
        print_success "Terraform is already installed: $(terraform version -json | jq -r '.terraform_version')"
    fi
    
    # Install jq if not present
    if ! command -v jq &> /dev/null; then
        print_status "Installing jq..."
        sudo apt update && sudo apt install jq -y
    else
        print_success "jq is already installed"
    fi
    
    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        print_status "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    else
        print_success "AWS CLI is already installed: $(aws --version)"
    fi
}

# Function to setup Terraform state backup
setup_state_backup() {
    print_status "Setting up Terraform state backup..."
    
    # Create backup directory
    mkdir -p "$BAK_DIR"
    
    # Restore previous state if it exists
    if [[ -f "$BAK_DIR/terraform.tfstate" ]]; then
        print_warning "Found existing Terraform state, restoring..."
        cp "$BAK_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate"
    fi
    
    if [[ -f "$BAK_DIR/terraform.tfstate.backup" ]]; then
        cp "$BAK_DIR/terraform.tfstate.backup" "$SCRIPT_DIR/terraform.tfstate.backup"
    fi
}

# Function to backup Terraform state
backup_state() {
    print_status "Backing up Terraform state..."
    
    if [[ -f "$SCRIPT_DIR/terraform.tfstate" ]]; then
        cp "$SCRIPT_DIR/terraform.tfstate" "$BAK_DIR/"
    fi
    
    if [[ -f "$SCRIPT_DIR/terraform.tfstate.backup" ]]; then
        cp "$SCRIPT_DIR/terraform.tfstate.backup" "$BAK_DIR/"
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

# Function to check required AWS permissions
check_aws_permissions() {
    print_status "Checking AWS permissions..."
    
    # Basic permission checks
    local permissions_ok=true
    
    # Check ECS permissions
    if ! aws ecs list-clusters &> /dev/null; then
        print_warning "ECS permissions may be limited"
        permissions_ok=false
    fi
    
    # Check EC2 VPC permissions  
    if ! aws ec2 describe-vpcs --max-items 1 &> /dev/null; then
        print_warning "VPC permissions may be limited"
        permissions_ok=false
    fi
    
    # Check IAM permissions
    if ! aws iam list-roles --max-items 1 &> /dev/null; then
        print_warning "IAM permissions may be limited"
        permissions_ok=false
    fi
    
    if [[ "$permissions_ok" == true ]]; then
        print_success "AWS permissions check passed"
    else
        print_warning "Some AWS permissions may be limited. Deployment may fail."
        print_warning "This is normal in AWS Academy Learner Lab environment"
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying Mock Test 02 infrastructure..."
    
    cd "$SCRIPT_DIR"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Remove plan file
    rm -f tfplan
    
    # Backup state after successful deployment
    backup_state
    
    print_success "Infrastructure deployment completed!"
}

# Function to display deployment summary
display_summary() {
    print_status "=== MOCK TEST 02 DEPLOYMENT SUMMARY ==="
    echo
    print_status "🏗️  Infrastructure Deployed:"
    echo "   • VPC with public/private subnets"
    echo "   • Application Load Balancer"
    echo "   • ECS Fargate cluster and service"
    echo "   • Service Discovery namespace"
    echo "   • Auto Scaling configuration"
    echo "   • CloudWatch monitoring"
    echo
    
    print_status "🎯 Challenge Focus: Container Orchestration & Service Discovery"
    echo "   • ECS/Fargate container management"
    echo "   • Application Load Balancer configuration"
    echo "   • Service discovery and networking"
    echo "   • Auto scaling and health checks"
    echo "   • Container security and permissions"
    echo
    
    # Get outputs from Terraform
    if terraform output &> /dev/null; then
        print_status "📊 Resource Information:"
        local alb_dns=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
        local cluster_name=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "Not available")
        local vpc_id=$(terraform output -raw vpc_id 2>/dev/null || echo "Not available")
        
        echo "   • ALB DNS Name: $alb_dns"
        echo "   • ECS Cluster: $cluster_name" 
        echo "   • VPC ID: $vpc_id"
        echo
    fi
    
    print_warning "⚠️  IMPORTANT NOTES:"
    echo "   • Infrastructure contains 12 intentional misconfigurations"
    echo "   • Use AWS Console/CLI to diagnose and fix issues"
    echo "   • Run './eval.sh' to check your progress"
    echo "   • Run './remediate.sh' to see solutions (instructor only)"
    echo "   • Run './teardown.sh' to clean up resources"
    echo
    
    print_status "🚀 Getting Started:"
    echo "   1. Run './eval.sh' to see all challenges"
    echo "   2. Use AWS Console to investigate issues"
    echo "   3. Fix one challenge at a time"
    echo "   4. Re-run './eval.sh' to verify fixes"
    echo "   5. Repeat until all challenges are ACCEPTED"
    echo
    
    print_success "Mock Test 02 is ready! Good luck with the challenges! 🎉"
}

# Main execution flow
main() {
    echo "=================================================="
    echo "  Ethnus AWS Training - Mock Test 02 Deployment"
    echo "  Focus: Container Orchestration & Service Discovery"
    echo "=================================================="
    echo
    
    # Check if script is being run from the correct directory
    if [[ ! -f "$SCRIPT_DIR/main.tf" ]]; then
        print_error "main.tf not found! Please run this script from the scripts/ directory"
        exit 1
    fi
    
    # Install required tools
    install_tools
    
    # Setup state management
    setup_state_backup
    
    # Check AWS setup
    check_aws_credentials
    check_aws_permissions
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Show summary
    display_summary
}

# Run main function
main "$@"
