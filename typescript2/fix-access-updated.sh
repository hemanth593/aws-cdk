#!/bin/bash

# Updated EKS Access Fix - Using Current AWS Methods
# Works with modern EKS authentication

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="prod-eks-sre-cluster"
AWS_REGION="us-east-1"
ADMIN_ROLE_ARN="arn:aws:iam::575108957879:role/devops-admins"
NODE_ROLE_ARN="arn:aws:iam::575108957879:role/prod-sre-workernode-role"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}EKS Cluster Access Fix (Updated)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Current AWS Identity:${NC}"
aws sts get-caller-identity
echo ""

# Check cluster authentication mode
echo -e "${YELLOW}Checking cluster authentication mode...${NC}"
AUTH_MODE=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} \
    --region ${AWS_REGION} \
    --query 'cluster.accessConfig.authenticationMode' \
    --output text 2>/dev/null || echo "NOT_SET")

echo "Authentication mode: ${AUTH_MODE}"
echo ""

if [ "$AUTH_MODE" = "API" ] || [ "$AUTH_MODE" = "API_AND_CONFIG_MAP" ]; then
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Method 1: Using EKS Access Entries API${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    
    # Create access entry
    echo -e "${YELLOW}Creating access entry...${NC}"
    aws eks create-access-entry \
        --cluster-name ${CLUSTER_NAME} \
        --principal-arn ${ADMIN_ROLE_ARN} \
        --region ${AWS_REGION} 2>&1 | tee /tmp/create-entry.log || true
    
    if grep -q "ResourceInUseException" /tmp/create-entry.log; then
        echo -e "${GREEN}✓ Access entry already exists${NC}"
    elif grep -q "created" /tmp/create-entry.log || grep -q "accessEntry" /tmp/create-entry.log; then
        echo -e "${GREEN}✓ Access entry created${NC}"
    else
        echo -e "${YELLOW}Note: Entry may already exist or creation status unclear${NC}"
    fi
    echo ""
    
    # List available policies
    echo -e "${YELLOW}Available EKS access policies:${NC}"
    aws eks list-access-policies --region ${AWS_REGION} --query 'accessPolicies[*].[name,arn]' --output table
    echo ""
    
    # Try to associate AmazonEKSAdminPolicy (the correct current policy)
    echo -e "${YELLOW}Associating AmazonEKSAdminPolicy...${NC}"
    aws eks associate-access-policy \
        --cluster-name ${CLUSTER_NAME} \
        --principal-arn ${ADMIN_ROLE_ARN} \
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy \
        --access-scope type=cluster \
        --region ${AWS_REGION} 2>&1 | tee /tmp/policy.log || true
    
    if grep -q "already associated\|associated" /tmp/policy.log || [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Policy associated${NC}"
    else
        # Try AmazonEKSClusterPolicy as fallback
        echo -e "${YELLOW}Trying AmazonEKSClusterPolicy...${NC}"
        aws eks associate-access-policy \
            --cluster-name ${CLUSTER_NAME} \
            --principal-arn ${ADMIN_ROLE_ARN} \
            --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterPolicy \
            --access-scope type=cluster \
            --region ${AWS_REGION} 2>&1 || true
    fi
    echo ""
    
else
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Method 2: Using aws-auth ConfigMap${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Cluster is using CONFIG_MAP authentication mode.${NC}"
    echo -e "${YELLOW}We need to create/update the aws-auth ConfigMap.${NC}"
    echo ""
    
    # Try to get current ConfigMap
    echo -e "${YELLOW}Checking for existing aws-auth ConfigMap...${NC}"
    if kubectl get configmap aws-auth -n kube-system 2>/dev/null; then
        echo -e "${GREEN}✓ ConfigMap exists${NC}"
        echo ""
        echo -e "${YELLOW}Current aws-auth ConfigMap:${NC}"
        kubectl get configmap aws-auth -n kube-system -o yaml
    else
        echo -e "${YELLOW}ConfigMap does not exist yet${NC}"
        echo ""
        echo -e "${RED}═══════════════════════════════════════════════${NC}"
        echo -e "${RED}AUTHENTICATION REQUIRED${NC}"
        echo -e "${RED}═══════════════════════════════════════════════${NC}"
        echo ""
        echo "The cluster needs the aws-auth ConfigMap to be created."
        echo "This requires access from the cluster creator or root account."
        echo ""
        echo -e "${BLUE}SOLUTION OPTIONS:${NC}"
        echo ""
        echo "1. Update cluster to API mode (enables access entries):"
        echo -e "${GREEN}   aws eks update-cluster-config \\"
        echo "     --name ${CLUSTER_NAME} \\"
        echo "     --region ${AWS_REGION} \\"
        echo "     --access-config authenticationMode=API_AND_CONFIG_MAP${NC}"
        echo ""
        echo "   Then wait 10-15 minutes and re-run this script."
        echo ""
        echo "2. Use AWS Console with admin permissions:"
        echo "   - Go to EKS Console"
        echo "   - Select cluster > Access tab"
        echo "   - Create access entry for: ${ADMIN_ROLE_ARN}"
        echo ""
        echo "3. If you have root account access, use it temporarily"
        echo ""
        echo "4. Apply ConfigMap manually if you have a session that created the cluster"
        echo ""
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Listing access entries...${NC}"
aws eks list-access-entries \
    --cluster-name ${CLUSTER_NAME} \
    --region ${AWS_REGION} 2>/dev/null || echo "Could not list access entries (may not be supported)"

echo ""
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION} --alias eks-cluster

echo ""
echo -e "${YELLOW}Testing cluster access...${NC}"
sleep 3  # Give a moment for credentials to propagate

if kubectl get nodes 2>&1 | grep -q "NAME\|No resources\|Running"; then
    echo -e "${GREEN}✓✓✓ SUCCESS! You now have cluster access ✓✓✓${NC}"
    echo ""
    kubectl get nodes
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}NEXT STEPS:${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "1. Deploy application:"
    echo -e "   ${BLUE}kubectl apply -f kubernetes/${NC}"
    echo ""
    echo "2. Install ALB Controller:"
    echo -e "   ${BLUE}./install-alb-controller.sh${NC}"
    echo ""
    echo "3. Check application:"
    echo -e "   ${BLUE}kubectl get all -n prod-hello${NC}"
    echo ""
else
    echo -e "${RED}✗ Still cannot access cluster${NC}"
    echo ""
    echo -e "${YELLOW}Additional troubleshooting steps:${NC}"
    echo ""
    echo "1. Try updating cluster authentication mode:"
    echo -e "   ${GREEN}aws eks update-cluster-config \\"
    echo "     --name ${CLUSTER_NAME} \\"
    echo "     --region ${AWS_REGION} \\"
    echo "     --access-config authenticationMode=API_AND_CONFIG_MAP${NC}"
    echo ""
    echo "2. Wait 10-15 minutes for the update to complete, then re-run this script"
    echo ""
    echo "3. Check update status:"
    echo -e "   ${GREEN}aws eks describe-update \\"
    echo "     --name ${CLUSTER_NAME} \\"
    echo "     --update-id <update-id-from-previous-command> \\"
    echo "     --region ${AWS_REGION}${NC}"
    echo ""
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}Script Complete${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"

# Cleanup
rm -f /tmp/create-entry.log /tmp/policy.log

