#!/bin/bash

# Script to generate Ingress manifest with actual subnet IDs
# This creates an ALB in AWS and optionally sets up Route53

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Generating Ingress Manifest with Subnet IDs${NC}"
echo ""

# Get VPC ID
echo -e "${YELLOW}Getting VPC ID...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=eks-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region us-east-1)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: Could not find VPC with tag Name=eks-vpc"
    exit 1
fi

echo "VPC ID: $VPC_ID"
echo ""

# Get Private Subnet IDs
echo -e "${YELLOW}Getting private subnet IDs...${NC}"
SUBNET_A=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=prod-eks-subnet-private-us-east-1a" \
    --query 'Subnets[0].SubnetId' \
    --output text \
    --region us-east-1)

SUBNET_B=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=prod-eks-subnet-private-us-east-1b" \
    --query 'Subnets[0].SubnetId' \
    --output text \
    --region us-east-1)

SUBNET_C=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=prod-eks-subnet-private-us-east-1c" \
    --query 'Subnets[0].SubnetId' \
    --output text \
    --region us-east-1)

echo "Private Subnet A: $SUBNET_A"
echo "Private Subnet B: $SUBNET_B"
echo "Private Subnet C: $SUBNET_C"
echo ""

# Create the ingress manifest
cat > kubernetes/03-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prod-hello-ingress
  namespace: prod-hello
  annotations:
    # Load Balancer Configuration
    alb.ingress.kubernetes.io/load-balancer-name: prod-hello-alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    
    # Subnet selection (private subnets for internal ALB)
    alb.ingress.kubernetes.io/subnets: ${SUBNET_A},${SUBNET_B},${SUBNET_C}
    
    # Tags for the ALB
    alb.ingress.kubernetes.io/tags: Environment=production,Application=prod-hello,ManagedBy=kubernetes,Component=prod-hello
    
    # Listener Configuration
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    
    # Load Balancer Attributes
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=600
    
    # Health Check Configuration
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '10'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '3'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/success-codes: '200-399'
    
    # Target Group Configuration
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30,stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=3600
    
    # External DNS annotation (requires external-dns to be installed)
    external-dns.alpha.kubernetes.io/hostname: pagidh.sre.practice.com
    external-dns.alpha.kubernetes.io/ttl: "300"
    
spec:
  ingressClassName: alb
  rules:
  - host: pagidh.sre.practice.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prod-hello-service
            port:
              number: 80
EOF

echo -e "${GREEN}✓ Ingress manifest generated: kubernetes/03-ingress.yaml${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Apply the ingress:"
echo -e "   ${BLUE}kubectl apply -f kubernetes/03-ingress.yaml${NC}"
echo ""
echo "2. Wait for ALB creation (2-3 minutes):"
echo -e "   ${BLUE}kubectl get ingress prod-hello-ingress -n prod-hello -w${NC}"
echo ""
echo "3. Get ALB DNS name:"
echo -e "   ${BLUE}kubectl get ingress prod-hello-ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'${NC}"
echo ""
echo "4. Option A - Install External-DNS for automatic Route53 (recommended):"
echo -e "   ${BLUE}./install-external-dns.sh${NC}"
echo ""
echo "5. Option B - Manually create Route53 record:"
echo -e "   ${BLUE}./create-route53-record.sh${NC}"
echo ""
