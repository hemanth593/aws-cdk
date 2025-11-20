#!/bin/bash

# Complete EKS Deployment Script with KMS, Auth, and Application
# This script deploys the complete infrastructure and application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="prod-eks-sre-cluster"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="575108957879"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Complete EKS Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check prerequisites
print_section "Checking Prerequisites"

echo -e "${YELLOW}Checking required tools...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Warning: helm is not installed (required for ALB controller)${NC}"
    echo -e "${YELLOW}Install helm: https://helm.sh/docs/intro/install/${NC}"
fi

if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}Warning: eksctl is not installed (required for ALB controller)${NC}"
    echo -e "${YELLOW}Install eksctl: https://eksctl.io/installation/${NC}"
fi

echo -e "${GREEN}✓ Required tools check passed${NC}"

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS credentials configured${NC}"
    echo -e "  Account ID: ${ACCOUNT_ID}"
    
    if [ "$ACCOUNT_ID" != "$AWS_ACCOUNT_ID" ]; then
        echo -e "${YELLOW}Warning: Account ID mismatch. Expected: ${AWS_ACCOUNT_ID}, Got: ${ACCOUNT_ID}${NC}"
        read -p "Continue anyway? [y/N]: " continue_mismatch
        if [[ ! $continue_mismatch =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

# Phase 1: CDK Infrastructure
print_section "Phase 1: Deploying CDK Infrastructure"

echo -e "${YELLOW}1. Installing dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    npm install
fi
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo -e "${YELLOW}2. Building TypeScript project...${NC}"
npm run build
echo -e "${GREEN}✓ Project built${NC}"

echo -e "${YELLOW}3. Checking CDK bootstrap...${NC}"
if ! aws cloudformation describe-stacks --stack-name CDKToolkit --region ${AWS_REGION} &> /dev/null; then
    echo -e "${YELLOW}CDK not bootstrapped. Bootstrapping now...${NC}"
    npx cdk bootstrap
else
    echo -e "${GREEN}✓ CDK already bootstrapped${NC}"
fi

echo -e "${YELLOW}4. Deploying infrastructure stacks...${NC}"
echo ""
echo "This will deploy the following stacks in order:"
echo "  1. EksVpcCdkStack"
echo "  2. EksAdminPolicyStack"
echo "  3. EksClusterRoleStack"
echo "  4. EksNodeGroupRoleStack"
echo "  5. EksKmsKeyStack (NEW - KMS encryption)"
echo "  6. EksClusterStack (with KMS encryption)"
echo "  7. EksLaunchTemplateStack"
echo "  8. EksNodeGroupSchedulerStack"
echo "  9. EksNodeGroupHelloStack"
echo ""

read -p "Continue with infrastructure deployment? [y/N]: " deploy_infra
if [[ $deploy_infra =~ ^[Yy]$ ]]; then
    npx cdk deploy --all --require-approval never
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
else
    echo -e "${YELLOW}Infrastructure deployment skipped${NC}"
    exit 0
fi

# Phase 2: Cluster Configuration
print_section "Phase 2: Configuring EKS Cluster"
#aws sts get-caller-identity
#aws eks describe-cluster --name prod-eks-sre-cluster --region us-east-1 --query 'cluster.accessConfig.authenticationMode' --output text
#aws eks create-access-entry --cluster-name prod-eks-sre-cluster --principal-arn arn:aws:iam::575108957879:role/devops-admins --region us-east-1
#aws eks list-access-policies --region us-east-1 --query 'accessPolicies[*].[name,arn]' --output table
#aws eks associate-access-policy --cluster-name prod-eks-sre-cluster --principal-arn arn:aws:iam::575108957879:role/devops-admins --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy --access-scope type=cluster --region us-east-1
#aws eks associate-access-policy --cluster-name prod-eks-sre-cluster --principal-arn arn:aws:iam::575108957879:role/devops-admins --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region us-east-1
#aws eks update-cluster-config --name ${CLUSTER_NAME} --region ${AWS_REGION} --access-config authenticationMode=API_AND_CONFIG_MAP

echo -e "${YELLOW}1. Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
echo -e "${GREEN}✓ Kubeconfig updated${NC}"

echo -e "${YELLOW}2. Applying aws-auth ConfigMap...${NC}"
if [ -f "kubernetes/aws-auth-configmap.yaml" ]; then
    kubectl apply -f kubernetes/aws-auth-configmap.yaml
    echo -e "${GREEN}✓ aws-auth ConfigMap applied${NC}"
    echo -e "${YELLOW}Waiting 30 seconds for RBAC to propagate...${NC}"
    sleep 30
else
    echo -e "${RED}Error: aws-auth-configmap.yaml not found${NC}"
    exit 1
fi

echo -e "${YELLOW}3. Verifying cluster access...${NC}"
kubectl get nodes
echo -e "${GREEN}✓ Cluster access verified${NC}"

# Phase 3: Install AWS Load Balancer Controller
print_section "Phase 3: Installing AWS Load Balancer Controller"

if command -v helm &> /dev/null && command -v eksctl &> /dev/null; then
    read -p "Install AWS Load Balancer Controller? [y/N]: " install_alb
    if [[ $install_alb =~ ^[Yy]$ ]]; then
        ./install-alb-controller.sh
    else
        echo -e "${YELLOW}ALB Controller installation skipped${NC}"
        echo -e "${YELLOW}You can install it later using: ./install-alb-controller.sh${NC}"
    fi
else
    echo -e "${YELLOW}Skipping ALB Controller installation (helm or eksctl not found)${NC}"
    echo -e "${YELLOW}Install manually using: ./install-alb-controller.sh${NC}"
fi

# Phase 4: Deploy Application
print_section "Phase 4: Deploying prod-hello Application"

read -p "Deploy prod-hello application now? [y/N]: " deploy_app
if [[ $deploy_app =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deploying application manifests...${NC}"
    
    # Apply manifests in order
    kubectl apply -f kubernetes/00-namespace.yaml
    echo -e "${GREEN}✓ Namespace created${NC}"
    
    kubectl apply -f kubernetes/01-deployment.yaml
    echo -e "${GREEN}✓ Deployment created${NC}"
    
    kubectl apply -f kubernetes/02-service.yaml
    echo -e "${GREEN}✓ Service created${NC}"
    
    kubectl apply -f kubernetes/03-ingress.yaml
    echo -e "${GREEN}✓ Ingress created${NC}"
    
    echo ""
    echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app=prod-hello -n prod-hello --timeout=300s || true
    
    echo ""
    echo -e "${GREEN}✓ Application deployed${NC}"
    
    # Show deployment status
    echo ""
    echo -e "${YELLOW}Deployment Status:${NC}"
    kubectl get pods -n prod-hello
    echo ""
    kubectl get svc -n prod-hello
    echo ""
    kubectl get ingress -n prod-hello
else
    echo -e "${YELLOW}Application deployment skipped${NC}"
    echo -e "${YELLOW}You can deploy later using: kubectl apply -f kubernetes/${NC}"
fi

# Phase 5: Setup Route53 (Manual)
print_section "Phase 5: Route53 Configuration"

echo -e "${YELLOW}To complete the setup, you need to create a Route53 record:${NC}"
echo ""
echo "1. Get the ALB DNS name:"
echo -e "${BLUE}   kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'${NC}"
echo ""
echo "2. Create an A record (ALIAS) in Route53:"
echo "   - Hosted Zone: pagidh.sre.practice.com"
echo "   - Record Name: pagidh.sre.practice.com"
echo "   - Type: A - IPv4 address"
echo "   - Alias: Yes"
echo "   - Alias Target: <ALB-DNS-from-step-1>"
echo ""
echo "Or use AWS CLI:"
echo -e "${BLUE}   ALB_DNS=\$(kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')${NC}"
echo -e "${BLUE}   HOSTED_ZONE_ID=\$(aws route53 list-hosted-zones-by-name --dns-name pagidh.sre.practice.com --query 'HostedZones[0].Id' --output text)${NC}"
echo -e "${BLUE}   ALB_ZONE_ID=\$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(DNSName, \`'\$ALB_DNS'\`)].CanonicalHostedZoneId' --output text)${NC}"
echo ""
echo -e "${BLUE}   cat > route53-change.json <<EOF"
echo -e "   {"
echo -e "     \"Changes\": [{"
echo -e "       \"Action\": \"UPSERT\","
echo -e "       \"ResourceRecordSet\": {"
echo -e "         \"Name\": \"pagidh.sre.practice.com\","
echo -e "         \"Type\": \"A\","
echo -e "         \"AliasTarget\": {"
echo -e "           \"HostedZoneId\": \"\$ALB_ZONE_ID\","
echo -e "           \"DNSName\": \"\$ALB_DNS\","
echo -e "           \"EvaluateTargetHealth\": false"
echo -e "         }"
echo -e "       }"
echo -e "     }]"
echo -e "   }"
echo -e "   EOF${NC}"
echo ""
echo -e "${BLUE}   aws route53 change-resource-record-sets --hosted-zone-id \$HOSTED_ZONE_ID --change-batch file://route53-change.json${NC}"
echo ""

# Summary
print_section "Deployment Summary"

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo -e "${GREEN}✓ Cluster configured with KMS encryption${NC}"
echo -e "${GREEN}✓ Role mapping applied (devops-admins → cluster admin)${NC}"

if [[ $install_alb =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"
fi

if [[ $deploy_app =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✓ prod-hello application deployed${NC}"
fi

echo ""
echo -e "${YELLOW}Quick Commands:${NC}"
echo ""
echo "# View cluster info"
echo -e "${BLUE}kubectl cluster-info${NC}"
echo ""
echo "# Check nodes"
echo -e "${BLUE}kubectl get nodes${NC}"
echo ""
echo "# Check application"
echo -e "${BLUE}kubectl get all -n prod-hello${NC}"
echo ""
echo "# Get ALB DNS"
echo -e "${BLUE}kubectl get ingress prod-hello-ingress -n prod-hello${NC}"
echo ""
echo "# View logs"
echo -e "${BLUE}kubectl logs -f deployment/prod-hello-deployment -n prod-hello${NC}"
echo ""
echo "# Test locally (port-forward)"
echo -e "${BLUE}kubectl port-forward -n prod-hello svc/prod-hello-service 8080:80${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
