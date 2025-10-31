# Project Files Index

## 📋 Overview

This package contains all the files needed to deploy a new EKS node group (`prod-hello-ng`) with a containerized application behind an internal Application Load Balancer.

## 📁 Files Delivered

### 🚀 Quick Start Documents
1. **[QUICK_START.md](QUICK_START.md)** - Start here! Fast deployment guide (15-25 min)
2. **[README.md](README.md)** - Comprehensive documentation with troubleshooting
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture diagrams and explanations

### 🐍 CDK Stack Files (Python)
4. **[eks_nodegroup_hello.py](eks_nodegroup_hello.py)** - Node group stack with dedicated security group
5. **[eks_alb.py](eks_alb.py)** - ALB stack (alternative to Ingress approach)
6. **[eks_k8s_resources.py](eks_k8s_resources.py)** - Kubernetes manifest generator
7. **[app_updated.py](app_updated.py)** - Updated app.py with all new stacks

### ☸️ Kubernetes Manifests
8. **[kubernetes-manifests.yaml](kubernetes-manifests.yaml)** - Complete K8s resources:
   - Namespace (prod-hello)
   - Deployment (1 replica)
   - Service (NodePort)
   - Ingress (creates ALB)

### 🔧 Deployment Scripts
9. **[deploy-prod-hello.sh](deploy-prod-hello.sh)** - Automated deployment script
10. **[test-prod-hello.sh](test-prod-hello.sh)** - Testing and verification script

---

## 🎯 What Gets Deployed

### Infrastructure (CDK)
- ✅ New EKS node group: `prod-hello-ng` (1 node)
- ✅ Security group: `prod-hello-ng-sg`
- ✅ Reuses launch template: `prod-scheduler-v2-lt`
- ✅ Internal ALB: `prod-eks-sre-hello-alb`
- ✅ ALB security group: `prod-eks-sre-hello-alb-sg`

### Kubernetes Resources
- ✅ Namespace: `prod-hello`
- ✅ Deployment with your ECR image
- ✅ Service exposing port 80
- ✅ Ingress creating and managing ALB

---

## 🚀 Quick Deployment Path

### Choose Your Approach:

#### Option A: Fully Automated (Recommended)
```bash
# 1. Update CDK project
cp eks_nodegroup_hello.py eks_vpc_cdk/
cp eks_k8s_resources.py eks_vpc_cdk/
cp eks_alb.py eks_vpc_cdk/
cp app_updated.py app.py

# 2. Deploy infrastructure
cdk deploy EksNodeGroupHelloStack

# 3. Deploy application
chmod +x deploy-prod-hello.sh
./deploy-prod-hello.sh

# 4. Test
chmod +x test-prod-hello.sh
./test-prod-hello.sh
```

#### Option B: Step-by-Step Manual
See [QUICK_START.md](QUICK_START.md) for detailed manual steps.

---

## 📖 Documentation Guide

### For First-Time Users
1. Read [QUICK_START.md](QUICK_START.md) - Get up and running fast
2. Run `deploy-prod-hello.sh` - Automated deployment
3. Run `test-prod-hello.sh` - Verify everything works

### For Understanding Architecture
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) - Understand the design
2. Review the CDK stack files - See implementation details

### For Troubleshooting
1. Check [README.md](README.md) - Comprehensive troubleshooting section
2. Run `test-prod-hello.sh` - Diagnostic checks
3. Review Kubernetes events: `kubectl describe pod -n prod-hello`

---

## 🔑 Key Information

| Item | Value |
|------|-------|
| **Cluster Name** | prod-eks-sre-cluster |
| **Region** | us-east-1 |
| **Account ID** | 575108957879 |
| **Node Group** | prod-hello-ng |
| **Namespace** | prod-hello |
| **Image** | 575108957879.dkr.ecr.us-east-1.amazonaws.com/hello/swatops13032:latest |
| **ALB Name** | prod-eks-sre-hello-alb |
| **ALB Type** | Internal (VPC-only) |
| **Port** | 80 |

---

## ✅ Pre-Deployment Checklist

Before deploying, ensure you have:
- [ ] AWS CLI configured with appropriate credentials
- [ ] kubectl installed and configured
- [ ] eksctl installed (for LB controller setup)
- [ ] Helm 3 installed (for LB controller)
- [ ] Existing EKS cluster is running
- [ ] VPC and subnets are available
- [ ] ECR image exists and is accessible
- [ ] IAM permissions for EKS, EC2, IAM, ELB

---

## 🎨 File Usage Matrix

| File | CDK Deploy | K8s Apply | Script Run | Reference |
|------|------------|-----------|------------|-----------|
| eks_nodegroup_hello.py | ✅ | ❌ | ❌ | ❌ |
| eks_alb.py | ⚠️ Optional | ❌ | ❌ | ❌ |
| eks_k8s_resources.py | ✅ | ❌ | ❌ | ❌ |
| app_updated.py | ✅ | ❌ | ❌ | ❌ |
| kubernetes-manifests.yaml | ❌ | ✅ | ✅ | ✅ |
| deploy-prod-hello.sh | ❌ | ✅ | ✅ | ❌ |
| test-prod-hello.sh | ❌ | ❌ | ✅ | ❌ |
| QUICK_START.md | ❌ | ❌ | ❌ | ✅ |
| README.md | ❌ | ❌ | ❌ | ✅ |
| ARCHITECTURE.md | ❌ | ❌ | ❌ | ✅ |

Legend:
- ✅ Primary use case
- ⚠️ Alternative/optional approach
- ❌ Not applicable

---

## 📝 Deployment Approaches

### Approach 1: AWS Load Balancer Controller (Recommended)
**Uses:** kubernetes-manifests.yaml + deploy-prod-hello.sh

**Pros:**
- Kubernetes-native (Ingress resource)
- Automatic ALB lifecycle management
- Easy updates and rollbacks
- Industry best practice

**Files needed:**
- eks_nodegroup_hello.py
- eks_k8s_resources.py
- kubernetes-manifests.yaml
- deploy-prod-hello.sh

### Approach 2: CDK-Managed ALB
**Uses:** eks_alb.py CDK stack

**Pros:**
- Direct AWS control
- Infrastructure as Code consistency
- Manual target management

**Files needed:**
- eks_nodegroup_hello.py
- eks_alb.py
- Manual target group registration

---

## 🔄 Update Process

### To Update the Application
```bash
# Update image tag in kubernetes-manifests.yaml
# Then:
kubectl apply -f kubernetes-manifests.yaml
kubectl rollout restart deployment/prod-hello-deployment -n prod-hello
```

### To Scale the Node Group
```bash
# Update scaling_config in eks_nodegroup_hello.py
cdk deploy EksNodeGroupHelloStack
```

### To Update CDK Stacks
```bash
# Modify stack files
cdk diff  # Review changes
cdk deploy EksNodeGroupHelloStack
```

---

## 🆘 Quick Help

### Something not working?
1. Run `./test-prod-hello.sh` for diagnostics
2. Check [README.md](README.md) troubleshooting section
3. Review pod logs: `kubectl logs -n prod-hello -l app=prod-hello`

### Need to understand the architecture?
1. See [ARCHITECTURE.md](ARCHITECTURE.md) for diagrams
2. Review traffic flow and component relationships

### First time deploying?
1. Follow [QUICK_START.md](QUICK_START.md) step by step
2. Use the automated script for easiest deployment

---

## 📞 Common Commands Reference

```bash
# Configure kubectl
aws eks update-kubeconfig --name prod-eks-sre-cluster --region us-east-1

# Check deployment status
kubectl get all -n prod-hello

# Get ALB DNS
kubectl get ingress -n prod-hello

# View logs
kubectl logs -n prod-hello -l app=prod-hello --tail=50

# Test from pod
kubectl run test --image=curlimages/curl -i --rm --restart=Never -- \
  curl http://prod-hello-service.prod-hello.svc.cluster.local

# Port forward for local testing
kubectl port-forward -n prod-hello svc/prod-hello-service 8080:80
```

---

## 📦 Package Contents Summary

| Type | Count | Files |
|------|-------|-------|
| Documentation | 3 | QUICK_START, README, ARCHITECTURE |
| CDK Stacks | 4 | nodegroup, alb, k8s_resources, app_updated |
| K8s Manifests | 1 | kubernetes-manifests.yaml |
| Scripts | 2 | deploy-prod-hello.sh, test-prod-hello.sh |
| **Total** | **10** | **Complete deployment package** |

---

## ⏱️ Estimated Time

| Task | Time |
|------|------|
| Reading documentation | 10-15 min |
| Updating CDK project | 2 min |
| CDK deployment | 5-10 min |
| Application deployment | 5-10 min |
| Testing and verification | 2-5 min |
| **Total (first time)** | **25-40 min** |
| **Total (subsequent)** | **10-15 min** |

---

## 🎓 Learning Path

**Beginner?** → QUICK_START.md → deploy-prod-hello.sh → test-prod-hello.sh

**Intermediate?** → README.md → Manual deployment → ARCHITECTURE.md

**Advanced?** → Review CDK stacks → Customize → Deploy with CDK

---

## ✨ Features Implemented

- ✅ Dedicated node group for prod-hello workload
- ✅ Namespace isolation (prod-hello)
- ✅ Internal ALB with automatic provisioning
- ✅ Dedicated security groups
- ✅ Health checks and monitoring
- ✅ ECR image deployment
- ✅ Node selector for pod placement
- ✅ Reusable launch template
- ✅ Multi-AZ deployment
- ✅ Infrastructure as Code (CDK)
- ✅ Automated deployment scripts
- ✅ Comprehensive documentation
- ✅ Testing and validation tools

---

**Ready to deploy? Start with [QUICK_START.md](QUICK_START.md)!**
