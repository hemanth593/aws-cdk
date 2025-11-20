#!/bin/bash

# Fix aws-auth ConfigMap - Manual Application Script
# This script helps apply the aws-auth ConfigMap when you don't have cluster access yet

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="prod-eks-sre-cluster"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="575108957879"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS-Auth ConfigMap Fix Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}The aws-auth ConfigMap needs to be created by the AWS user/role that created the cluster.${NC}"
echo ""
echo -e "${YELLOW}Current AWS Identity:${NC}"
aws sts get-caller-identity

echo ""
echo -e "${YELLOW}Method 1: Using eksctl (Recommended)${NC}"
echo ""

# Check if eksctl is installed
if command -v eksctl &> /dev/null; then
    echo -e "${GREEN}✓ eksctl is installed${NC}"
    echo ""
    echo -e "${YELLOW}Creating identity mapping for devops-admins role...${NC}"
    
    eksctl create iamidentitymapping \
        --cluster ${CLUSTER_NAME} \
        --region ${AWS_REGION} \
        --arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/devops-admins \
        --username devops-admin \
        --group system:masters \
        --no-duplicate-arns
    
    echo -e "${GREEN}✓ Identity mapping created${NC}"
    echo ""
    echo -e "${YELLOW}Verifying aws-auth ConfigMap...${NC}"
    kubectl get configmap aws-auth -n kube-system -o yaml
    
else
    echo -e "${YELLOW}eksctl is not installed.${NC}"
    echo ""
    echo -e "${YELLOW}Method 2: Manual Application${NC}"
    echo ""
    echo "You need to apply the aws-auth ConfigMap as the IAM user/role that created the cluster."
    echo ""
    echo "1. Switch to the IAM identity that created the cluster, or"
    echo "2. Use CloudShell from the AWS Console (if you have console access), or"
    echo "3. Install eksctl and use Method 1"
    echo ""
    echo -e "${YELLOW}To install eksctl:${NC}"
    echo "  macOS: brew install eksctl"
    echo "  Linux: https://eksctl.io/installation/"
    echo ""
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Alternative: Direct kubectl apply${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "If you are the creator of the cluster, you can try:"
echo ""
echo -e "${YELLOW}kubectl apply -f - <<EOF"
cat kubernetes/aws-auth-configmap.yaml
echo "EOF${NC}"
echo ""
