# Complete ALB + Route53 Setup Guide

## 🎯 Your Question Answered

**Q:** How to create ALB in AWS account and automatically point Route53 to it?

**A:** Use AWS Load Balancer Controller (creates ALB) + External-DNS (creates Route53 record automatically)

---

## 🚀 **Solution: Two Approaches**

### **Approach 1: Automatic (Recommended) - External-DNS**
External-DNS watches Ingress resources and automatically creates/updates Route53 records.

### **Approach 2: Manual - Script-based**
Create Route53 record manually after ALB is provisioned.

---

## 📋 **Complete Setup Steps**

### **Step 1: Generate Ingress with Real Subnet IDs**

```bash
# This script gets your actual private subnet IDs and generates the ingress
./generate-ingress.sh
```

**What it does:**
- Looks up your VPC
- Finds private subnet IDs
- Generates `kubernetes/03-ingress.yaml` with actual subnet IDs

---

### **Step 2: Choose Your Approach**

#### **Option A: Automatic (Recommended)**

```bash
# Install External-DNS
./install-external-dns.sh
```

**What External-DNS does:**
1. Watches for Ingress resources with annotation: `external-dns.alpha.kubernetes.io/hostname`
2. When ALB is created, automatically creates Route53 A record (ALIAS)
3. Keeps DNS records in sync with ALB
4. Cleans up DNS records when Ingress is deleted

**Benefits:**
- ✅ Fully automatic
- ✅ No manual intervention
- ✅ Self-healing (updates if ALB changes)
- ✅ Cleanup on delete

#### **Option B: Manual**

```bash
# Deploy ingress first
kubectl apply -f kubernetes/03-ingress.yaml

# Wait for ALB (2-3 minutes)
kubectl get ingress prod-hello-ingress -n prod-hello -w

# Then create Route53 record
./create-route53-record.sh
```

---

## 📝 **Detailed Walkthrough**

### **Phase 1: Prepare Ingress**

```bash
# 1. Generate ingress with real subnet IDs
./generate-ingress.sh

# 2. Review the generated file
cat kubernetes/03-ingress.yaml
```

**Key annotations in the Ingress:**

```yaml
annotations:
  # Load Balancer Controller creates ALB in AWS
  alb.ingress.kubernetes.io/load-balancer-name: prod-hello-alb
  alb.ingress.kubernetes.io/scheme: internal
  alb.ingress.kubernetes.io/subnets: subnet-xxx,subnet-yyy,subnet-zzz  # Real IDs
  
  # External-DNS creates Route53 record
  external-dns.alpha.kubernetes.io/hostname: pagidh.sre.practice.com
```

---

### **Phase 2: Install External-DNS (Automatic Approach)**

```bash
# Install External-DNS
./install-external-dns.sh
```

**What happens:**
1. Creates IAM policy for Route53 access
2. Creates IAM service account (IRSA)
3. Installs External-DNS via Helm
4. External-DNS starts watching for Ingress resources

**Verify installation:**
```bash
# Check External-DNS pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f
```

---

### **Phase 3: Deploy Application**

```bash
# Deploy all resources
kubectl apply -f kubernetes/

# Or one by one
kubectl apply -f kubernetes/00-namespace.yaml
kubectl apply -f kubernetes/01-deployment.yaml
kubectl apply -f kubernetes/02-service.yaml
kubectl apply -f kubernetes/03-ingress.yaml
```

---

### **Phase 4: Wait for Provisioning**

```bash
# Watch Ingress status
kubectl get ingress prod-hello-ingress -n prod-hello -w

# Look for ADDRESS field to be populated (ALB DNS)
```

**Timeline:**
- **0-2 min**: Ingress created, ALB provisioning starts
- **2-3 min**: ALB becomes active, DNS name appears
- **3-4 min**: External-DNS creates Route53 record
- **4-5 min**: DNS propagates globally

---

### **Phase 5: Verify**

```bash
# 1. Check Ingress has ALB
kubectl get ingress prod-hello-ingress -n prod-hello

# 2. Get ALB DNS
ALB_DNS=$(kubectl get ingress prod-hello-ingress -n prod-hello \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS

# 3. Check Route53 record (with External-DNS)
dig pagidh.sre.practice.com

# 4. Test access (from within VPC for internal ALB)
curl http://pagidh.sre.practice.com
```

---

## 🔍 **How It Works**

### **Architecture Flow:**

```
1. kubectl apply ingress
        ↓
2. AWS Load Balancer Controller sees ingress
        ↓
3. Creates ALB in AWS account
   - Internal ALB
   - In private subnets
   - Target type: IP (pod IPs)
        ↓
4. External-DNS sees ingress with hostname annotation
        ↓
5. Gets ALB DNS from ingress status
        ↓
6. Creates Route53 A record (ALIAS)
   - pagidh.sre.practice.com → ALB DNS
        ↓
7. DNS propagates
        ↓
8. Users can access: pagidh.sre.practice.com
```

---

## 📊 **Comparison: Manual vs Automatic**

| Feature | Manual | External-DNS |
|---------|--------|--------------|
| **Setup complexity** | Low | Medium |
| **Ongoing effort** | High | None |
| **Updates** | Manual | Automatic |
| **Deletion** | Manual cleanup | Auto cleanup |
| **Multiple ingresses** | Script each | All automatic |
| **Recommended for** | Testing | Production |

---

## 🛠️ **Troubleshooting**

### **Ingress has no address**

```bash
# Check ALB Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress events
kubectl describe ingress prod-hello-ingress -n prod-hello

# Common issues:
# - Incorrect subnet IDs
# - IAM permissions missing
# - ALB Controller not installed
```

### **Route53 record not created**

```bash
# Check External-DNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns

# Common issues:
# - IAM permissions for Route53
# - Hosted zone doesn't exist
# - Domain filter mismatch
# - Annotation missing/incorrect
```

### **DNS doesn't resolve**

```bash
# Check Route53 record exists
aws route53 list-resource-record-sets \
  --hosted-zone-id Z123456 \
  | grep pagidh.sre.practice.com

# Test DNS resolution
dig pagidh.sre.practice.com
nslookup pagidh.sre.practice.com

# Wait 2-5 minutes for propagation
```

### **Can't access via domain**

```bash
# For internal ALB, test from within VPC:
# - EC2 instance in same VPC
# - VPN connected to VPC
# - AWS Systems Manager Session Manager

# Check ALB health checks
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names prod-hello-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

---

## 📝 **Generated Files**

After running the scripts, you'll have:

```
kubernetes/
├── 00-namespace.yaml          # Namespace
├── 01-deployment.yaml         # Application
├── 02-service.yaml            # Service
└── 03-ingress.yaml            # ✨ Generated with real subnet IDs
```

**The ingress will have:**
- Real subnet IDs (not placeholders)
- External-DNS annotation
- ALB configuration
- Health check settings

---

## 🎯 **Quick Reference Commands**

```bash
# Generate ingress
./generate-ingress.sh

# Install External-DNS (automatic Route53)
./install-external-dns.sh

# OR manually create Route53 record
./create-route53-record.sh

# Deploy application
kubectl apply -f kubernetes/

# Check status
kubectl get all -n prod-hello
kubectl get ingress -n prod-hello

# Get ALB DNS
kubectl get ingress prod-hello-ingress -n prod-hello \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test DNS
dig pagidh.sre.practice.com

# Check External-DNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f
```

---

## 🔐 **Security Considerations**

### **Internal ALB:**
- Only accessible from within VPC
- Use VPN or AWS PrivateLink for external access
- Consider AWS Global Accelerator for global access

### **IAM Permissions:**
External-DNS needs:
- `route53:ChangeResourceRecordSets` on hosted zone
- `route53:ListHostedZones`
- `route53:ListResourceRecordSets`

---

## 📦 **Complete Deployment**

```bash
# Full workflow:

# 1. Infrastructure (already done)
cdk deploy --all

# 2. Cluster access (already done)
./fix-access-updated.sh

# 3. ALB Controller (already done)
./install-alb-controller.sh

# 4. Generate ingress with real subnets
./generate-ingress.sh

# 5. Install External-DNS (for automatic Route53)
./install-external-dns.sh

# 6. Deploy application
kubectl apply -f kubernetes/

# 7. Wait and verify
kubectl get ingress -n prod-hello -w
dig pagidh.sre.practice.com
```

---

## ✅ **Summary**

**Your Ingress DOES create an ALB in AWS** - the AWS Load Balancer Controller handles this!

**What you needed:**
1. ✅ Real subnet IDs in ingress → Use `./generate-ingress.sh`
2. ✅ Automatic Route53 creation → Use `./install-external-dns.sh`

**Result:**
- ALB created in AWS account ✅
- Route53 record auto-created ✅
- DNS points to ALB ✅
- No manual intervention ✅

---

**Scripts Created:**
- `generate-ingress.sh` - Gets real subnet IDs
- `install-external-dns.sh` - Automatic Route53
- `create-route53-record.sh` - Manual Route53

**Run them in order and you're done!** 🎉
