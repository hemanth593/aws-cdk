# Quick Deployment Summary

## What Was Created

### 1. CDK Stack Files (Python)
- **eks_nodegroup_hello.py** - New node group `prod-hello-ng` with dedicated security group
- **eks_alb.py** - Internal ALB infrastructure (alternative approach)
- **eks_k8s_resources.py** - K8s manifest generator
- **app_updated.py** - Updated app.py with new stacks

### 2. Kubernetes Manifest
- **kubernetes-manifests.yaml** - Complete K8s resources:
  - Namespace: prod-hello
  - Deployment: prod-hello-deployment (1 replica)
  - Service: prod-hello-service (NodePort)
  - Ingress: prod-hello-ingress (creates internal ALB)

### 3. Deployment Script
- **deploy-prod-hello.sh** - Automated deployment script

## Fastest Path to Deployment

### Step 1: Update Your CDK Project (2 minutes)
```bash
# Copy new stack files to your project
cp eks_nodegroup_hello.py eks_vpc_cdk/
cp eks_k8s_resources.py eks_vpc_cdk/
cp eks_alb.py eks_vpc_cdk/

# Replace app.py
cp app_updated.py app.py
```

### Step 2: Deploy Infrastructure (5-10 minutes)
```bash
# Deploy new CDK stacks
cdk deploy EksNodeGroupHelloStack
```

### Step 3: Deploy Application (5-10 minutes)
```bash
# Make script executable and run
chmod +x deploy-prod-hello.sh
./deploy-prod-hello.sh
```

### Step 4: Test (1 minute)
```bash
# Get ALB DNS
kubectl get ingress -n prod-hello

# Test from within VPC (EC2 or pod)
curl http://<alb-dns-name>
```

## Important Notes

✅ **Reuses Existing Resources:**
- Same launch template as prod-scheduler-v2
- Same IAM roles (prod-sre-workernode-role)
- Same VPC and subnets

✅ **New Dedicated Resources:**
- Node group: prod-hello-ng (1 node)
- Security group: prod-hello-ng-sg
- Namespace: prod-hello
- Internal ALB: prod-eks-sre-hello-alb
- ALB Security group: prod-eks-sre-hello-alb-sg

⚠️ **Internal ALB:**
- Can only be accessed from within the VPC
- Test from EC2 instance or pod in the cluster

🔑 **Key Configuration:**
- Image: 575108957879.dkr.ecr.us-east-1.amazonaws.com/hello/swatops13032:latest
- Port: 80
- Node selector ensures pods run only on prod-hello-ng nodes

## Two Approaches Available

### Approach 1: AWS Load Balancer Controller + Ingress (Recommended)
- Uses `kubernetes-manifests.yaml` and `deploy-prod-hello.sh`
- ALB automatically created and managed by Ingress
- More Kubernetes-native
- **This is what the automated script uses**

### Approach 2: CDK-Managed ALB
- Uses `eks_alb.py` CDK stack
- ALB created directly via CDK
- Requires manual target registration
- Good for more control over ALB configuration

## Verification Commands

```bash
# Check nodes
kubectl get nodes -l eks.amazonaws.com/nodegroup=prod-hello-ng

# Check namespace
kubectl get all -n prod-hello

# Check ingress
kubectl get ingress -n prod-hello
kubectl describe ingress prod-hello-ingress -n prod-hello

# Check ALB in AWS
aws elbv2 describe-load-balancers --names prod-eks-sre-hello-alb

# Check pods are running
kubectl get pods -n prod-hello -o wide

# Test from pod
kubectl run test-curl --image=curlimages/curl -i --rm --restart=Never -- \
  curl http://prod-hello-service.prod-hello.svc.cluster.local
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod -n prod-hello
kubectl logs -n prod-hello <pod-name>
```

**ALB not created?**
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
kubectl describe ingress prod-hello-ingress -n prod-hello
```

**Cannot pull image?**
- Ensure node IAM role has ECR permissions (AmazonEC2ContainerRegistryReadOnly)
- Check image URI is correct
- Verify image exists: `aws ecr describe-images --repository-name hello/swatops13032`

## Next Steps After Deployment

1. Monitor pod health: `kubectl get pods -n prod-hello -w`
2. Check ALB health: `kubectl describe ingress -n prod-hello`
3. Test endpoint from within VPC
4. Set up monitoring/logging if needed
5. Configure autoscaling if required

## Estimated Total Time
- First-time setup: **15-25 minutes**
- Subsequent deployments: **5-10 minutes**
