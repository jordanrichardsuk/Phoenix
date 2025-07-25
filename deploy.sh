#!/bin/bash

# Phoenix Chatbot Deployment Script
# This script deploys the CloudFormation stack and uploads the frontend to S3

set -e  # Exit on any error

# Default Configuration
TEMPLATE_FILE="phoenix-claude.yaml"
HTML_FILE="index.html"
REGION="us-east-1"
UPDATE_ONLY=false
UPDATE_STACK=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
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

# Usage function
usage() {
    echo "Usage: $0 [--dev|--test|--uat|--prod] [--region REGION] [--update|--update-stack]"
    echo ""
    echo "Environment flags:"
    echo "  --dev     Deploy to development environment"
    echo "  --test    Deploy to test environment"
    echo "  --uat     Deploy to UAT/staging environment"
    echo "  --prod    Deploy to production environment"
    echo ""
    echo "Options:"
    echo "  --region REGION    AWS region (default: us-east-1)"
    echo "  --update          Update frontend only (skip stack deployment)"
    echo "  --update-stack    Update CloudFormation stack (Lambda functions, etc.)"
    echo ""
    echo "Examples:"
    echo "  $0 --dev"
    echo "  $0 --prod --region us-west-2"
    echo "  $0 --uat --update"
    echo "  $0 --prod --update-stack"
    exit 1
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev)
            ENVIRONMENT="dev"
            STACK_NAME="phoenix-dev"
            shift
            ;;
        --test)
            ENVIRONMENT="test"
            STACK_NAME="phoenix-test"
            shift
            ;;
        --uat)
            ENVIRONMENT="uat"
            STACK_NAME="phoenix-uat"
            shift
            ;;
        --prod)
            ENVIRONMENT="prod"
            STACK_NAME="phoenix-prod"
            shift
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --update)
            UPDATE_ONLY=true
            shift
            ;;
        --update-stack)
            UPDATE_STACK=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate that an environment was selected
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "You must specify an environment: --dev, --test, --uat, or --prod"
    usage
fi

# Check if AWS CLI is installed and configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_success "AWS CLI is configured and working"
}

# Check if required files exist
check_files() {
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "CloudFormation template file '$TEMPLATE_FILE' not found"
        exit 1
    fi
    
    if [[ ! -f "$HTML_FILE" ]]; then
        print_error "HTML file '$HTML_FILE' not found"
        exit 1
    fi
    
    print_success "Required files found"
}

# Deploy CloudFormation stack
deploy_stack() {
    print_info "Deploying CloudFormation stack: $STACK_NAME"
    
    # Create a unique S3 bucket for CloudFormation templates if it doesn't exist
    CF_BUCKET="phoenix-cf-templates-$(date +%s)-$RANDOM"
    print_info "Creating S3 bucket for CloudFormation template: $CF_BUCKET"
    
    aws s3 mb "s3://$CF_BUCKET" --region "$REGION" 2>/dev/null || {
        print_warning "Bucket creation failed, it may already exist or have a naming conflict"
        # Use a fallback bucket name
        CF_BUCKET="phoenix-cf-templates-$(whoami)-$(date +%Y%m%d)"
        aws s3 mb "s3://$CF_BUCKET" --region "$REGION" 2>/dev/null || true
    }
    
    # Upload template to S3
    print_info "Uploading template to S3..."
    aws s3 cp "$TEMPLATE_FILE" "s3://$CF_BUCKET/phoenix-claude.yaml" --region "$REGION"
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to upload template to S3"
        exit 1
    fi
    
    # Deploy using S3 bucket
    aws cloudformation deploy \
        --template-file "$TEMPLATE_FILE" \
        --stack-name "$STACK_NAME" \
        --s3-bucket "$CF_BUCKET" \
        --parameter-overrides Environment="$ENVIRONMENT" \
        --capabilities CAPABILITY_IAM \
        --region "$REGION" \
        --no-fail-on-empty-changeset
    
    if [[ $? -eq 0 ]]; then
        print_success "CloudFormation stack deployed successfully"
    else
        print_error "CloudFormation deployment failed"
        exit 1
    fi
    
    # Clean up the temporary S3 bucket
    print_info "Cleaning up temporary S3 bucket..."
    aws s3 rb "s3://$CF_BUCKET" --force --region "$REGION" 2>/dev/null || true
}

# Get stack outputs
get_stack_outputs() {
    print_info "Retrieving stack outputs..."
    
    # Get S3 bucket name
    S3_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
        --output text \
        --region "$REGION")
    
    # Get API endpoint
    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
        --output text \
        --region "$REGION")
    
    # Get CloudFront distribution ID
    CF_DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
        --output text \
        --region "$REGION")
    
    # Get website URL
    WEBSITE_URL=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
        --output text \
        --region "$REGION")
    
    if [[ -z "$S3_BUCKET" ]] || [[ -z "$API_ENDPOINT" ]]; then
        print_error "Failed to retrieve stack outputs"
        exit 1
    fi
    
    print_success "Stack outputs retrieved"
}

# Upload frontend to S3
upload_frontend() {
    print_info "Uploading frontend to S3..."
    
    # Create a temporary file with API endpoint replaced
    TEMP_HTML=$(mktemp)
    sed "s|{{API_ENDPOINT}}|$API_ENDPOINT|g" "$HTML_FILE" > "$TEMP_HTML"
    
    # Upload to S3
    aws s3 cp "$TEMP_HTML" "s3://$S3_BUCKET/index.html" \
        --content-type "text/html" \
        --cache-control "max-age=300" \
        --region "$REGION"
    
    if [[ $? -eq 0 ]]; then
        print_success "Frontend uploaded successfully"
    else
        print_error "Failed to upload frontend"
        rm "$TEMP_HTML"
        exit 1
    fi
    
    # Clean up temporary file
    rm "$TEMP_HTML"
    
    # Upload error.html if it exists
    if [[ -f "error.html" ]]; then
        aws s3 cp "error.html" "s3://$S3_BUCKET/error.html" \
            --content-type "text/html" \
            --cache-control "max-age=300" \
            --region "$REGION"
    fi
}

# Invalidate CloudFront cache
invalidate_cache() {
    if [[ -n "$CF_DISTRIBUTION_ID" ]]; then
        print_info "Invalidating CloudFront cache..."
        
        aws cloudfront create-invalidation \
            --distribution-id "$CF_DISTRIBUTION_ID" \
            --paths "/*" \
            --region "$REGION" &> /dev/null
        
        if [[ $? -eq 0 ]]; then
            print_success "CloudFront cache invalidation started"
        else
            print_warning "Failed to invalidate CloudFront cache"
        fi
    fi
}

# Print deployment summary
print_summary() {
    echo ""
    echo "🔥 Phoenix Chatbot Deployment Complete!"
    echo "======================================"
    print_info "Environment: $ENVIRONMENT"
    print_info "Stack Name: $STACK_NAME"
    print_info "Region: $REGION"
    echo ""
    print_success "Website URL: $WEBSITE_URL"
    print_success "API Endpoint: $API_ENDPOINT"
    echo ""
    echo "Deployment completed successfully!"
    echo ""
}

# Main execution
main() {
    echo "🔥 Phoenix Chatbot Deployment Script"
    echo "===================================="
    echo ""
    print_info "Configuration:"
    print_info "  Stack Name: $STACK_NAME"
    print_info "  Environment: $ENVIRONMENT"
    print_info "  Region: $REGION"
    echo ""
    
    # Check prerequisites
    check_aws_cli
    check_files
    
    if [[ "$UPDATE_ONLY" == true ]]; then
        print_info "Update-only mode: Skipping stack deployment"
    elif [[ "$UPDATE_STACK" == true ]]; then
        print_info "Updating CloudFormation stack..."
        deploy_stack
    else
        # Deploy CloudFormation stack
        deploy_stack
    fi
    
    # Get stack outputs
    get_stack_outputs
    
    # Upload frontend
    upload_frontend
    
    # Invalidate cache
    invalidate_cache
    
    # Print summary
    print_summary
}

# Run the main function
main