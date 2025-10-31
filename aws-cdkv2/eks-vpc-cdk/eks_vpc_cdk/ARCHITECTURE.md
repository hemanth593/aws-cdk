# Architecture Diagram - prod-hello EKS Deployment

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           AWS Account: 575108957879                         │
│                           Region: us-east-1                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                    VPC: 192.168.0.0/16                              │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │  │              EKS Cluster: prod-eks-sre-cluster               │ │   │
│  │  │              Kubernetes Version: 1.33                        │ │   │
│  │  │                                                               │ │   │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │   │
│  │  │  │        Namespace: prod-hello                           │ │ │   │
│  │  │  │                                                         │ │ │   │
│  │  │  │  ┌──────────────────────────────────────────────────┐ │ │ │   │
│  │  │  │  │  Deployment: prod-hello-deployment              │ │ │ │   │
│  │  │  │  │  Replicas: 1                                     │ │ │ │   │
│  │  │  │  │                                                  │ │ │ │   │
│  │  │  │  │  ┌────────────────────────────────────────────┐ │ │ │ │   │
│  │  │  │  │  │  Pod                                        │ │ │ │ │   │
│  │  │  │  │  │  Image: ECR Image                          │ │ │ │ │   │
│  │  │  │  │  │  575108957879.dkr.ecr.us-east-1.          │ │ │ │ │   │
│  │  │  │  │  │    amazonaws.com/hello/swatops13032:latest │ │ │ │ │   │
│  │  │  │  │  │  Port: 80                                  │ │ │ │ │   │
│  │  │  │  │  │  Node Selector:                            │ │ │ │ │   │
│  │  │  │  │  │    eks.amazonaws.com/nodegroup=            │ │ │ │ │   │
│  │  │  │  │  │      prod-hello-ng                         │ │ │ │ │   │
│  │  │  │  │  └────────────────────────────────────────────┘ │ │ │ │   │
│  │  │  │  └──────────────────────────────────────────────────┘ │ │ │   │
│  │  │  │                                                         │ │ │   │
│  │  │  │  ┌──────────────────────────────────────────────────┐ │ │ │   │
│  │  │  │  │  Service: prod-hello-service                    │ │ │ │   │
│  │  │  │  │  Type: NodePort                                  │ │ │ │   │
│  │  │  │  │  Port: 80 → TargetPort: 80                      │ │ │ │   │
│  │  │  │  │  Selector: app=prod-hello                       │ │ │ │   │
│  │  │  │  └──────────────────────────────────────────────────┘ │ │ │   │
│  │  │  │                                                         │ │ │   │
│  │  │  │  ┌──────────────────────────────────────────────────┐ │ │ │   │
│  │  │  │  │  Ingress: prod-hello-ingress                    │ │ │ │   │
│  │  │  │  │  Class: alb                                      │ │ │ │   │
│  │  │  │  │  Annotations:                                    │ │ │ │   │
│  │  │  │  │    - scheme: internal                           │ │ │ │   │
│  │  │  │  │    - target-type: ip                            │ │ │ │   │
│  │  │  │  │    - load-balancer-name:                        │ │ │ │   │
│  │  │  │  │        prod-eks-sre-hello-alb                   │ │ │ │   │
│  │  │  │  └──────────────────────────────────────────────────┘ │ │ │   │
│  │  │  └────────────────────────────────────────────────────────┘ │ │   │
│  │  │                                                               │ │   │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │   │
│  │  │  │     Node Group: prod-hello-ng                          │ │ │   │
│  │  │  │     Instance Type: t3a.xlarge (from launch template)  │ │ │   │
│  │  │  │     Desired/Min/Max: 1/1/1                             │ │ │   │
│  │  │  │     AMI: AL2023_x86_64_STANDARD                        │ │ │   │
│  │  │  │     Launch Template: prod-scheduler-v2-lt              │ │ │   │
│  │  │  │     Security Group: prod-hello-ng-sg                   │ │ │   │
│  │  │  │     Subnets: Private (192.168.48.0/20,                │ │ │   │
│  │  │  │              192.168.64.0/20, 192.168.80.0/20)        │ │ │   │
│  │  │  │     IAM Role: prod-sre-workernode-role                 │ │ │   │
│  │  │  └────────────────────────────────────────────────────────┘ │ │   │
│  │  │                                                               │ │   │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │   │
│  │  │  │     Node Group: prod-scheduler-v2 (EXISTING)           │ │ │   │
│  │  │  │     Desired/Min/Max: 2/1/2                             │ │ │   │
│  │  │  └────────────────────────────────────────────────────────┘ │ │   │
│  │  └──────────────────────────────────────────────────────────────┘ │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │  │  Internal Application Load Balancer                          │ │   │
│  │  │  Name: prod-eks-sre-hello-alb                                │ │   │
│  │  │  Scheme: internal                                             │ │   │
│  │  │  Subnets: Private subnets (all 3 AZs)                        │ │   │
│  │  │  Security Group: prod-eks-sre-hello-alb-sg                   │ │   │
│  │  │    Ingress: 192.168.0.0/16 → Port 80                         │ │   │
│  │  │  Target Group: prod-hello-tg                                 │ │   │
│  │  │    Target Type: IP (Pod IPs)                                 │ │   │
│  │  │    Health Check: HTTP:80 /                                   │ │   │
│  │  │                                                               │ │   │
│  │  │  Listener:                                                    │ │   │
│  │  │    Port: 80 (HTTP) → Forward to prod-hello-tg               │ │   │
│  │  └──────────────────────────────────────────────────────────────┘ │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐ │   │
│  │  │                     Subnets Layout                            │ │   │
│  │  │                                                               │ │   │
│  │  │  Public Subnets:                                             │ │   │
│  │  │    - us-east-1a: 192.168.0.0/20                              │ │   │
│  │  │    - us-east-1b: 192.168.16.0/20                             │ │   │
│  │  │    - us-east-1c: 192.168.32.0/20                             │ │   │
│  │  │                                                               │ │   │
│  │  │  Private Subnets (Worker Nodes & ALB):                       │ │   │
│  │  │    - us-east-1a: 192.168.48.0/20                             │ │   │
│  │  │    - us-east-1b: 192.168.64.0/20                             │ │   │
│  │  │    - us-east-1c: 192.168.80.0/20                             │ │   │
│  │  └──────────────────────────────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                 ECR Repository                                      │   │
│  │  Name: hello/swatops13032                                          │   │
│  │  URI: 575108957879.dkr.ecr.us-east-1.amazonaws.com/               │   │
│  │       hello/swatops13032:latest                                    │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                 IAM Roles                                           │   │
│  │                                                                      │   │
│  │  Cluster Role: prod-sre-eks-cluster-role                           │   │
│  │    - AmazonEKSClusterPolicy                                         │   │
│  │    - AmazonEKSVPCResourceController                                │   │
│  │    - GetCloudwatchMetrics-for-EKS                                  │   │
│  │                                                                      │   │
│  │  Worker Node Role: prod-sre-workernode-role                        │   │
│  │    - AmazonEC2ContainerRegistryReadOnly                            │   │
│  │    - AmazonEKS_CNI_Policy                                          │   │
│  │    - AmazonEKSWorkerNodePolicy                                     │   │
│  │    - AmazonSSMManagedInstanceCore                                  │   │
│  │    - AmazonSSMPatchAssociation                                     │   │
│  │    - AllowWAF                                                       │   │
│  │    - EC2Tags                                                        │   │
│  │    - GetCloudwatchMetrics-for-EKS                                  │   │
│  │                                                                      │   │
│  │  AWS LB Controller Role: (Created by eksctl)                       │   │
│  │    - AWSLoadBalancerControllerIAMPolicy                            │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
1. Request initiated from within VPC
   │
   ├─→ Internal ALB (prod-eks-sre-hello-alb)
   │   Port: 80
   │   Security Group: prod-eks-sre-hello-alb-sg
   │   DNS: <alb-name>.<region>.elb.amazonaws.com
   │
   ├─→ Target Group (prod-hello-tg)
   │   Target Type: IP (Pod IPs)
   │   Health Check: HTTP:80 /
   │
   ├─→ Kubernetes Service (prod-hello-service)
   │   Type: NodePort
   │   Namespace: prod-hello
   │   Port: 80
   │
   └─→ Pod (prod-hello-deployment)
       Container Port: 80
       Image: 575108957879.dkr.ecr.us-east-1.amazonaws.com/
              hello/swatops13032:latest
       Node: prod-hello-ng node group
```

## Security Groups

```
┌────────────────────────────────────────────────────┐
│  prod-eks-sre-hello-alb-sg                         │
│  (ALB Security Group)                              │
│                                                     │
│  Inbound:                                          │
│    - Port 80 (HTTP) from 192.168.0.0/16           │
│                                                     │
│  Outbound:                                         │
│    - All traffic                                   │
└────────────────────────────────────────────────────┘
           │
           │ Forwards to
           ▼
┌────────────────────────────────────────────────────┐
│  prod-hello-ng-sg                                  │
│  (Node Group Security Group)                       │
│                                                     │
│  Inbound:                                          │
│    - Port 80 from 192.168.0.0/16                  │
│    - All traffic from 192.168.0.0/16              │
│                                                     │
│  Outbound:                                         │
│    - All traffic                                   │
└────────────────────────────────────────────────────┘
           │
           │ Node hosts pod
           ▼
┌────────────────────────────────────────────────────┐
│  EKS Cluster Primary Security Group                │
│  (Automatically created by EKS)                    │
│  - Allows cluster-pod-node communication           │
└────────────────────────────────────────────────────┘
```

## CDK Stack Dependencies

```
EksVpcCdkStack
    │
    ├─→ EksClusterStack
    │       │
    │       └─→ EksLaunchTemplateStack
    │               │
    │               ├─→ EksNodeGroupSchedulerStack (existing)
    │               │
    │               └─→ EksNodeGroupHelloStack (NEW)
    │                       │
    │                       ├─→ EksK8sResourcesStack (NEW)
    │                       │
    │                       └─→ EksAlbStack (NEW - optional)
    │
    ├─→ EksClusterRoleStack
    ├─→ EksNodeGroupRoleStack
    └─→ EksAdminPolicyStack
```

## Components Summary

| Component | Name | Type | Details |
|-----------|------|------|---------|
| VPC | eks-vpc | AWS VPC | 192.168.0.0/16 |
| Cluster | prod-eks-sre-cluster | EKS Cluster | Kubernetes 1.33 |
| Node Group 1 | prod-scheduler-v2 | EKS Node Group | 2 nodes (existing) |
| Node Group 2 | prod-hello-ng | EKS Node Group | 1 node (new) |
| Launch Template | prod-scheduler-v2-lt | EC2 Launch Template | t3a.xlarge, Shared |
| Namespace | prod-hello | K8s Namespace | Isolated namespace |
| Deployment | prod-hello-deployment | K8s Deployment | 1 replica |
| Service | prod-hello-service | K8s Service | NodePort, Port 80 |
| Ingress | prod-hello-ingress | K8s Ingress | ALB controller |
| ALB | prod-eks-sre-hello-alb | Application Load Balancer | Internal, Port 80 |
| Target Group | prod-hello-tg | ALB Target Group | IP targets |
| Container Image | swatops13032:latest | ECR Image | Port 80 |

## Key Features

✅ **Dedicated Node Group**: Pods run only on prod-hello-ng nodes
✅ **Namespace Isolation**: All resources in prod-hello namespace
✅ **Internal ALB**: Not exposed to internet, VPC-only access
✅ **Automated ALB Management**: AWS Load Balancer Controller handles ALB lifecycle
✅ **Health Checks**: ALB monitors pod health automatically
✅ **Reusable Components**: Shares launch template and IAM roles
✅ **Security Groups**: Dedicated SGs for ALB and node group
✅ **Multi-AZ**: Spans 3 availability zones for HA

## Network Connectivity

- **Pods**: Use CNI plugin, get IPs from VPC CIDR
- **Service**: ClusterIP from service CIDR (10.100.0.0/16)
- **ALB**: Internal DNS name, resolvable within VPC
- **Internet Access**: Nodes use NAT Gateway for egress
- **ECR Access**: Nodes pull images via NAT Gateway
