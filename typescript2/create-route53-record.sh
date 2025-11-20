#!/bin/bash

# Manual Route53 Record Creation Script
# Creates an A record (ALIAS) pointing to the ALB

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN="pagidh.sre.practice.com"
AWS_REGION="us-east-1"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Route53 Record Creation${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

# Get ALB DNS from Ingress
echo -e "${YELLOW}Getting ALB DNS from Ingress...${NC}"
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    echo -e "${RED}✗ ALB DNS not found. Is the Ingress created?${NC}"
    echo ""
    echo "Check ingress status:"
    echo -e "${BLUE}kubectl get ingress prod-hello-ingress -n prod-hello${NC}"
    echo ""
    echo "The ALB takes 2-3 minutes to provision. Wait and try again."
    exit 1
fi

echo -e "${GREEN}✓ ALB DNS: ${ALB_DNS}${NC}"
echo ""

# Get ALB Hosted Zone ID
echo -e "${YELLOW}Getting ALB Hosted Zone ID...${NC}"
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?DNSName=='${ALB_DNS}'].CanonicalHostedZoneId" \
    --output text \
    --region ${AWS_REGION})

if [ -z "$ALB_ZONE_ID" ]; then
    echo -e "${RED}✗ Could not get ALB Hosted Zone ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ALB Hosted Zone ID: ${ALB_ZONE_ID}${NC}"
echo ""

# Get Route53 Hosted Zone ID
echo -e "${YELLOW}Getting Route53 Hosted Zone ID...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name ${DOMAIN} \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text \
    --region ${AWS_REGION} | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}✗ Could not find hosted zone for ${DOMAIN}${NC}"
    echo "Please create the hosted zone first:"
    echo -e "${BLUE}aws route53 create-hosted-zone --name ${DOMAIN} --caller-reference $(date +%s)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Route53 Hosted Zone ID: ${HOSTED_ZONE_ID}${NC}"
echo ""

# Create change batch JSON
echo -e "${YELLOW}Creating Route53 change batch...${NC}"
cat > /tmp/route53-change.json <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${DOMAIN}",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "${ALB_ZONE_ID}",
        "DNSName": "${ALB_DNS}",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
EOF

echo -e "${GREEN}✓ Change batch created${NC}"
echo ""

# Show what will be created
echo -e "${YELLOW}Will create the following record:${NC}"
echo "  Domain: ${DOMAIN}"
echo "  Type: A (ALIAS)"
echo "  Target: ${ALB_DNS}"
echo ""

read -p "Continue? [y/N]: " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Apply the change
echo -e "${YELLOW}Creating Route53 record...${NC}"
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file:///tmp/route53-change.json \
    --query 'ChangeInfo.Id' \
    --output text)

echo -e "${GREEN}✓ Route53 record created${NC}"
echo "  Change ID: ${CHANGE_ID}"
echo ""

# Wait for change to propagate
echo -e "${YELLOW}Waiting for DNS propagation...${NC}"
aws route53 wait resource-record-sets-changed --id ${CHANGE_ID}

echo -e "${GREEN}✓ DNS record propagated${NC}"
echo ""

# Verify
echo -e "${YELLOW}Verifying DNS resolution...${NC}"
sleep 5  # Give DNS a moment to propagate

if dig +short ${DOMAIN} | grep -q .; then
    echo -e "${GREEN}✓ DNS resolution working${NC}"
    echo ""
    dig ${DOMAIN}
else
    echo -e "${YELLOW}DNS may still be propagating. Wait a few minutes and check:${NC}"
    echo -e "${BLUE}dig ${DOMAIN}${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Route53 Record Created!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  Domain: ${DOMAIN}"
echo "  Points to: ${ALB_DNS}"
echo "  Type: A (ALIAS)"
echo ""
echo -e "${YELLOW}Test access (from within VPC for internal ALB):${NC}"
echo -e "${BLUE}curl http://${DOMAIN}${NC}"
echo ""
echo -e "${YELLOW}View Route53 record:${NC}"
echo -e "${BLUE}aws route53 list-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} | grep -A 10 ${DOMAIN}${NC}"
echo ""

# Cleanup
rm -f /tmp/route53-change.json
