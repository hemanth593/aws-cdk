# Deployment Checklist for prod-hello

Use this checklist to ensure a smooth deployment of the prod-hello node group and application.

---

## Pre-Deployment Checklist

### ✅ Prerequisites Verification

- [ ] **AWS CLI installed and configured**
  ```bash
  aws --version
  aws sts get-caller-identity
  ```

- [ ] **kubectl installed**
  ```bash
  kubectl version --client
  ```

- [ ] **eksctl installed**
  ```bash
  eksctl version
  ```

- [ ] **Helm 3 installed**
  ```bash
  helm version
  ```

- [ ] **CDK installed**
  ```bash
  cdk --version
  ```

### ✅ AWS Resources Verification

- [ ] **EKS cluster exists and is active**
  ```bash
  aws eks describe-cluster --name prod-eks-sre-cluster --region us-east-1
  ```

- [ ] **VPC and subnets are available**
  ```bash
  aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-vpc"
  ```

- [ ] **ECR image exists**
  ```bash
  aws ecr describe-images \
    --repository-name hello/swatops13032 \
    --region us-east-1
  ```

- [ ] **IAM roles exist**
  ```bash
  aws iam get-role --role-name prod-sre-eks-cluster-role
  aws iam get-role --role-name prod-sre-workernode-role
  ```

- [ ] **Launch template exists**
  ```bash
  aws ec2 describe-launch-templates \
    --launch-template-names prod-scheduler-v2-lt
  ```

### ✅ Permissions Verification

- [ ] **Can create EKS node groups**
- [ ] **Can create EC2 security groups**
- [ ] **Can create ELB resources**
- [ ] **Can modify IAM roles/policies**
- [ ] **Can access ECR repositories**

---

## Deployment Checklist

### Phase 1: CDK Infrastructure Setup (5-10 minutes)

- [ ] **1.1 Copy CDK stack files to project**
  ```bash
  cp eks_nodegroup_hello.py eks_vpc_cdk/
  cp eks_k8s_resources.py eks_vpc_cdk/
  cp eks_alb.py eks_vpc_cdk/
  ```

- [ ] **1.2 Update app.py**
  ```bash
  cp app_updated.py app.py
  # OR manually merge the changes
  ```

- [ ] **1.3 Synthesize CDK to check for errors**
  ```bash
  cdk synth EksNodeGroupHelloStack
  ```

- [ ] **1.4 Deploy node group stack**
  ```bash
  cdk deploy EksNodeGroupHelloStack
  ```

- [ ] **1.5 Verify node group creation**
  ```bash
  aws eks describe-nodegroup \
    --cluster-name prod-eks-sre-cluster \
    --nodegroup-name prod-hello-ng
  ```

- [ ] **1.6 Configure kubectl**
  ```bash
  aws eks update-kubeconfig \
    --name prod-eks-sre-cluster \
    --region us-east-1
  ```

- [ ] **1.7 Verify node is ready**
  ```bash
  kubectl get nodes -l eks.amazonaws.com/nodegroup=prod-hello-ng
  ```

### Phase 2: AWS Load Balancer Controller Setup (5-10 minutes)

- [ ] **2.1 Create IAM OIDC provider**
  ```bash
  eksctl utils associate-iam-oidc-provider \
    --region=us-east-1 \
    --cluster=prod-eks-sre-cluster \
    --approve
  ```

- [ ] **2.2 Download IAM policy**
  ```bash
  curl -o iam-policy.json \
    https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json
  ```

- [ ] **2.3 Create IAM policy**
  ```bash
  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
  ```

- [ ] **2.4 Create service account**
  ```bash
  eksctl create iamserviceaccount \
    --cluster=prod-eks-sre-cluster \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::575108957879:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region=us-east-1 \
    --approve
  ```

- [ ] **2.5 Add Helm repository**
  ```bash
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  ```

- [ ] **2.6 Install AWS Load Balancer Controller**
  ```bash
  helm install aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=prod-eks-sre-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=us-east-1
  ```

- [ ] **2.7 Verify controller is running**
  ```bash
  kubectl get deployment -n kube-system aws-load-balancer-controller
  kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=aws-load-balancer-controller \
    --timeout=120s
  ```

### Phase 3: Application Deployment (3-5 minutes)

- [ ] **3.1 Review Kubernetes manifests**
  ```bash
  cat kubernetes-manifests.yaml
  ```

- [ ] **3.2 Apply Kubernetes manifests**
  ```bash
  kubectl apply -f kubernetes-manifests.yaml
  ```

- [ ] **3.3 Verify namespace created**
  ```bash
  kubectl get namespace prod-hello
  ```

- [ ] **3.4 Verify deployment created**
  ```bash
  kubectl get deployment -n prod-hello
  ```

- [ ] **3.5 Wait for pod to be ready**
  ```bash
  kubectl wait --namespace prod-hello \
    --for=condition=available deployment/prod-hello-deployment \
    --timeout=300s
  ```

- [ ] **3.6 Check pod status**
  ```bash
  kubectl get pods -n prod-hello -o wide
  ```

- [ ] **3.7 Check pod logs**
  ```bash
  kubectl logs -n prod-hello -l app=prod-hello
  ```

- [ ] **3.8 Verify service created**
  ```bash
  kubectl get svc -n prod-hello
  ```

- [ ] **3.9 Verify ingress created**
  ```bash
  kubectl get ingress -n prod-hello
  ```

### Phase 4: ALB Verification (2-3 minutes)

- [ ] **4.1 Wait for ALB to be provisioned (2-3 minutes)**
  ```bash
  # Check ingress status every 30 seconds
  watch kubectl get ingress -n prod-hello
  ```

- [ ] **4.2 Get ALB DNS name**
  ```bash
  kubectl get ingress prod-hello-ingress -n prod-hello \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```

- [ ] **4.3 Verify ALB exists in AWS**
  ```bash
  aws elbv2 describe-load-balancers --names prod-eks-sre-hello-alb
  ```

- [ ] **4.4 Check ALB target group**
  ```bash
  aws elbv2 describe-target-groups \
    --names prod-hello-tg
  ```

- [ ] **4.5 Check target health**
  ```bash
  TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
    --names prod-hello-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  
  aws elbv2 describe-target-health \
    --target-group-arn $TARGET_GROUP_ARN
  ```

### Phase 5: Testing (2-5 minutes)

- [ ] **5.1 Test service internally**
  ```bash
  kubectl run test-svc --image=curlimages/curl -i --rm --restart=Never -- \
    curl http://prod-hello-service.prod-hello.svc.cluster.local
  ```

- [ ] **5.2 Get ALB endpoint**
  ```bash
  ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  echo "ALB DNS: $ALB_DNS"
  ```

- [ ] **5.3 Test ALB from pod**
  ```bash
  kubectl run test-alb --image=curlimages/curl -i --rm --restart=Never -- \
    curl -v http://$ALB_DNS
  ```

- [ ] **5.4 Test ALB from EC2 instance (if available)**
  ```bash
  # SSH into an EC2 instance in the VPC
  curl http://$ALB_DNS
  ```

- [ ] **5.5 Test using port-forward (alternative)**
  ```bash
  kubectl port-forward -n prod-hello svc/prod-hello-service 8080:80
  # In another terminal:
  curl http://localhost:8080
  ```

### Phase 6: Validation (2-3 minutes)

- [ ] **6.1 Run automated test script**
  ```bash
  chmod +x test-prod-hello.sh
  ./test-prod-hello.sh
  ```

- [ ] **6.2 Verify all resources are healthy**
  ```bash
  kubectl get all -n prod-hello
  ```

- [ ] **6.3 Check for any errors in events**
  ```bash
  kubectl get events -n prod-hello --sort-by='.lastTimestamp'
  ```

- [ ] **6.4 Verify security groups**
  ```bash
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=prod-hello-ng-sg"
  
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=prod-eks-sre-hello-alb-sg"
  ```

- [ ] **6.5 Document ALB endpoint**
  ```bash
  echo "ALB Endpoint: http://$ALB_DNS" >> deployment-info.txt
  ```

---

## Post-Deployment Checklist

### ✅ Documentation

- [ ] **Record ALB DNS name** for future reference
- [ ] **Document any custom configurations** made
- [ ] **Update team documentation** with new service details
- [ ] **Create monitoring dashboard** (if applicable)

### ✅ Monitoring & Logging

- [ ] **Set up CloudWatch alarms** for pod/node health
- [ ] **Configure application logging** to CloudWatch Logs
- [ ] **Set up ALB access logs** (if needed)
- [ ] **Create custom metrics** (if applicable)

### ✅ Security

- [ ] **Review security group rules** for least privilege
- [ ] **Verify IAM roles** have minimum required permissions
- [ ] **Check network policies** (if using Calico/Network Policies)
- [ ] **Audit ECR image** for vulnerabilities

### ✅ Operations

- [ ] **Create runbook** for common operations
- [ ] **Document rollback procedure**
- [ ] **Set up backup strategy** (if needed)
- [ ] **Plan for updates/maintenance**

---

## Troubleshooting Checklist

### If Pods Are Not Starting

- [ ] Check pod events: `kubectl describe pod -n prod-hello`
- [ ] Check pod logs: `kubectl logs -n prod-hello <pod-name>`
- [ ] Verify image exists: `aws ecr describe-images --repository-name hello/swatops13032`
- [ ] Check node has ECR permissions
- [ ] Verify node selector matches: `kubectl get nodes --show-labels | grep prod-hello-ng`

### If ALB Is Not Created

- [ ] Check ingress events: `kubectl describe ingress prod-hello-ingress -n prod-hello`
- [ ] Check LB controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
- [ ] Verify IAM service account: `kubectl get serviceaccount -n kube-system aws-load-balancer-controller`
- [ ] Check for subnet tags for ALB
- [ ] Verify VPC has sufficient IPs

### If Cannot Access ALB

- [ ] Confirm ALB is internal (not internet-facing)
- [ ] Verify testing from within VPC
- [ ] Check security group rules
- [ ] Verify target health: `aws elbv2 describe-target-health --target-group-arn <arn>`
- [ ] Check pod is running and healthy

### If Node Group Has Issues

- [ ] Check node group status: `aws eks describe-nodegroup ...`
- [ ] Verify launch template exists
- [ ] Check IAM role for node group
- [ ] Review CloudWatch Logs for node bootstrap errors
- [ ] Verify subnets have available IPs

---

## Rollback Checklist

### If Deployment Fails

- [ ] **Delete Kubernetes resources**
  ```bash
  kubectl delete -f kubernetes-manifests.yaml
  ```

- [ ] **Delete node group (if needed)**
  ```bash
  cdk destroy EksNodeGroupHelloStack
  ```

- [ ] **Remove AWS Load Balancer Controller (if needed)**
  ```bash
  helm uninstall aws-load-balancer-controller -n kube-system
  ```

- [ ] **Clean up IAM resources**
  ```bash
  eksctl delete iamserviceaccount \
    --cluster=prod-eks-sre-cluster \
    --name=aws-load-balancer-controller \
    --namespace=kube-system
  ```

---

## Success Criteria

All items below should be ✅:

- [ ] Node group `prod-hello-ng` is active with 1 node
- [ ] Namespace `prod-hello` exists
- [ ] Deployment has 1/1 ready replica
- [ ] Service is accessible within cluster
- [ ] Ingress shows ALB hostname
- [ ] ALB is provisioned and healthy
- [ ] Target group shows healthy targets
- [ ] Can curl ALB endpoint from within VPC
- [ ] No errors in pod logs
- [ ] No errors in controller logs
- [ ] Security groups are properly configured
- [ ] All CDK stacks deployed successfully

---

## Completion Sign-Off

**Deployment Date:** _______________

**Deployed By:** _______________

**ALB Endpoint:** _______________

**Notes:** 

---

**Status:** ☐ In Progress | ☐ Completed Successfully | ☐ Failed/Rolled Back

---

## Quick Command Reference

```bash
# Get everything
kubectl get all -n prod-hello

# Watch deployment
kubectl get pods -n prod-hello -w

# Get ALB DNS
kubectl get ingress -n prod-hello -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test from pod
kubectl run test --image=curlimages/curl -i --rm --restart=Never -- curl http://<ALB-DNS>

# View logs
kubectl logs -n prod-hello -l app=prod-hello --tail=50 -f

# Check health
aws elbv2 describe-target-health --target-group-arn <arn>
```

---

**Pro Tip:** Use the automated scripts for faster deployment:
```bash
./deploy-prod-hello.sh    # Full deployment
./test-prod-hello.sh      # Testing and validation
```
