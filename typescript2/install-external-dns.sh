#!/bin/bash

# External-DNS Installation Script
# Automatically creates/updates Route53 records from Kubernetes Ingress

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

CLUSTER_NAME="prod-eks-sre-cluster"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="575108957879"
HOSTED_ZONE_DOMAIN="pagidh.sre.practice.com"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}External-DNS Installation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}✗ eksctl not found${NC}"
    echo "Install eksctl: https://eksctl.io/installation/"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm not found${NC}"
    echo "Install helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Get Hosted Zone ID
echo -e "${YELLOW}Getting Route53 Hosted Zone ID...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name ${HOSTED_ZONE_DOMAIN} \
    --query "HostedZones[?Name=='${HOSTED_ZONE_DOMAIN}.'].Id" \
    --output text \
    --region ${AWS_REGION} | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}✗ Could not find hosted zone for ${HOSTED_ZONE_DOMAIN}${NC}"
    echo "Please create the hosted zone first"
    exit 1
fi

echo -e "${GREEN}✓ Hosted Zone ID: ${HOSTED_ZONE_ID}${NC}"
echo ""

# Create IAM Policy
echo -e "${YELLOW}Creating IAM Policy for External-DNS...${NC}"

POLICY_NAME="ExternalDNSPolicy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

# Check if policy already exists
if aws iam get-policy --policy-arn ${POLICY_ARN} &> /dev/null; then
    echo -e "${GREEN}✓ IAM Policy already exists${NC}"
else
    cat > /tmp/external-dns-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/${HOSTED_ZONE_ID}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

    aws iam create-policy \
        --policy-name ${POLICY_NAME} \
        --policy-document file:///tmp/external-dns-policy.json
    
    echo -e "${GREEN}✓ IAM Policy created${NC}"
fi
echo ""

# Create IAM Service Account
echo -e "${YELLOW}Creating IAM Service Account for External-DNS...${NC}"

eksctl create iamserviceaccount \
    --cluster=${CLUSTER_NAME} \
    --namespace=kube-system \
    --name=external-dns \
    --role-name=ExternalDNSRole \
    --attach-policy-arn=${POLICY_ARN} \
    --approve \
    --override-existing-serviceaccounts \
    --region=${AWS_REGION}

echo -e "${GREEN}✓ IAM Service Account created${NC}"
echo ""

# Install External-DNS using Helm
echo -e "${YELLOW}Installing External-DNS...${NC}"

# Add bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install or upgrade External-DNS
helm upgrade --install external-dns bitnami/external-dns \
    --namespace kube-system \
    --set serviceAccount.create=false \
    --set serviceAccount.name=external-dns \
    --set provider=aws \
    --set aws.region=${AWS_REGION} \
    --set policy=sync \
    --set registry=txt \
    --set txtOwnerId=${HOSTED_ZONE_ID} \
    --set domainFilters[0]=${HOSTED_ZONE_DOMAIN} \
    --set sources[0]=ingress \
    --set sources[1]=service \
    --set interval=1m \
    --set logLevel=info

echo -e "${GREEN}✓ External-DNS installed${NC}"
echo ""

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/external-dns -n kube-system

echo -e "${GREEN}✓ External-DNS is running${NC}"
echo ""

# Show pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}How it works:${NC}"
echo "1. External-DNS watches for Ingress resources with the annotation:"
echo "   external-dns.alpha.kubernetes.io/hostname: pagidh.sre.practice.com"
echo ""
echo "2. When it finds an Ingress, it automatically creates/updates Route53 records"
echo ""
echo "3. The DNS record will point to the ALB created by the Ingress"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Apply your ingress with the external-dns annotation:"
echo -e "   ${BLUE}kubectl apply -f kubernetes/03-ingress.yaml${NC}"
echo ""
echo "2. Wait for ALB to be created (2-3 minutes)"
echo ""
echo "3. Check External-DNS logs:"
echo -e "   ${BLUE}kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f${NC}"
echo ""
echo "4. Verify Route53 record (takes 1-2 minutes):"
echo -e "   ${BLUE}dig pagidh.sre.practice.com${NC}"
echo ""
echo "5. Test access (from within VPC for internal ALB):"
echo -e "   ${BLUE}curl http://pagidh.sre.practice.com${NC}"
echo ""
