#!/bin/bash

# EKS CDK Deployment Script
# This script helps deploy the EKS infrastructure step by step

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS CDK Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS credentials configured${NC}"
    echo -e "  Account ID: ${ACCOUNT_ID}"
else
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

# Install dependencies
echo ""
echo -e "${YELLOW}Installing dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# Build the project
echo ""
echo -e "${YELLOW}Building TypeScript project...${NC}"
npm run build
echo -e "${GREEN}✓ Project built successfully${NC}"

# Bootstrap CDK (if needed)
echo ""
echo -e "${YELLOW}Checking CDK bootstrap status...${NC}"
read -p "Do you want to bootstrap CDK? (required for first-time setup) [y/N]: " bootstrap
if [[ $bootstrap =~ ^[Yy]$ ]]; then
    npx cdk bootstrap
    echo -e "${GREEN}✓ CDK bootstrapped${NC}"
fi

# Synthesize stacks
echo ""
echo -e "${YELLOW}Synthesizing CloudFormation templates...${NC}"
npx cdk synth > /dev/null
echo -e "${GREEN}✓ Templates synthesized successfully${NC}"

# Show stack list
echo ""
echo -e "${YELLOW}Available stacks:${NC}"
npx cdk list

# Deployment options
echo ""
echo -e "${GREEN}Deployment Options:${NC}"
echo "1. Deploy all stacks (recommended for first deployment)"
echo "2. Deploy specific stacks"
echo "3. Show stack differences (cdk diff)"
echo "4. Exit"
echo ""
read -p "Select an option [1-4]: " option

case $option in
    1)
        echo ""
        echo -e "${YELLOW}Deploying all stacks...${NC}"
        echo -e "${YELLOW}This will deploy stacks in the following order:${NC}"
        echo "  1. EksVpcCdkStack"
        echo "  2. EksAdminPolicyStack"
        echo "  3. EksClusterRoleStack"
        echo "  4. EksNodeGroupRoleStack"
        echo "  5. EksClusterStack"
        echo "  6. EksLaunchTemplateStack"
        echo "  7. EksNodeGroupSchedulerStack"
        echo "  8. EksNodeGroupHelloStack"
        echo ""
        read -p "Continue with deployment? [y/N]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            npx cdk deploy --all --require-approval never
            echo -e "${GREEN}✓ All stacks deployed successfully!${NC}"
            
            # Update kubeconfig
            echo ""
            echo -e "${YELLOW}Updating kubeconfig...${NC}"
            REGION=$(aws configure get region || echo "us-east-1")
            aws eks update-kubeconfig --name prod-eks-sre-cluster --region $REGION
            echo -e "${GREEN}✓ Kubeconfig updated${NC}"
            
            # Show cluster info
            echo ""
            echo -e "${GREEN}Cluster Information:${NC}"
            kubectl get nodes 2>/dev/null || echo "Waiting for nodes to be ready..."
        else
            echo -e "${YELLOW}Deployment cancelled${NC}"
        fi
        ;;
    2)
        echo ""
        echo -e "${YELLOW}Available stacks:${NC}"
        npx cdk list
        echo ""
        read -p "Enter stack name to deploy: " stack_name
        npx cdk deploy $stack_name
        echo -e "${GREEN}✓ Stack deployed successfully!${NC}"
        ;;
    3)
        echo ""
        read -p "Enter stack name (or 'all' for all stacks): " stack_name
        if [ "$stack_name" == "all" ]; then
            npx cdk diff
        else
            npx cdk diff $stack_name
        fi
        ;;
    4)
        echo -e "${YELLOW}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify cluster: kubectl get nodes"
echo "2. Check pods: kubectl get pods --all-namespaces"
echo "3. Deploy workloads to your cluster"
echo ""
echo -e "${YELLOW}To destroy the infrastructure:${NC}"
echo "  npm run destroy"
echo ""
