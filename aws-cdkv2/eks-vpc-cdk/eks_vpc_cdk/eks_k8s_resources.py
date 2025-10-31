from aws_cdk import (
    Stack,
    aws_eks as eks,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_create_cluster import EksClusterStack
import json

class EksK8sResourcesStack(Stack):
    def __init__(self, scope: Construct, id: str, 
                 eks_cluster_stack: EksClusterStack,
                 **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Get the EKS cluster reference
        cluster = eks_cluster_stack.cluster
        cluster_name = cluster.name
        
        # Create namespace manifest
        namespace_manifest = {
            "apiVersion": "v1",
            "kind": "Namespace",
            "metadata": {
                "name": "prod-hello",
                "labels": {
                    "name": "prod-hello"
                }
            }
        }
        
        # Create deployment manifest
        deployment_manifest = {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {
                "name": "prod-hello-deployment",
                "namespace": "prod-hello",
                "labels": {
                    "app": "prod-hello"
                }
            },
            "spec": {
                "replicas": 1,
                "selector": {
                    "matchLabels": {
                        "app": "prod-hello"
                    }
                },
                "template": {
                    "metadata": {
                        "labels": {
                            "app": "prod-hello"
                        }
                    },
                    "spec": {
                        "containers": [
                            {
                                "name": "hello-container",
                                "image": "575108957879.dkr.ecr.us-east-1.amazonaws.com/hello/swatops13032:latest",
                                "ports": [
                                    {
                                        "containerPort": 80,
                                        "protocol": "TCP"
                                    }
                                ],
                                "imagePullPolicy": "Always"
                            }
                        ],
                        "nodeSelector": {
                            "eks.amazonaws.com/nodegroup": "prod-hello-ng"
                        }
                    }
                }
            }
        }
        
        # Create service manifest
        service_manifest = {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {
                "name": "prod-hello-service",
                "namespace": "prod-hello",
                "labels": {
                    "app": "prod-hello"
                }
            },
            "spec": {
                "type": "NodePort",
                "selector": {
                    "app": "prod-hello"
                },
                "ports": [
                    {
                        "protocol": "TCP",
                        "port": 80,
                        "targetPort": 80
                    }
                ]
            }
        }
        
        # Apply manifests using kubectl
        # Note: These will be applied via CDK's Kubernetes manifest resources
        # We'll use CfnJson to store the manifests and output them
        
        # Store manifests as outputs for manual application or reference
        CfnOutput(
            self, "NamespaceManifest",
            value=json.dumps(namespace_manifest),
            description="Kubernetes namespace manifest for prod-hello"
        )
        
        CfnOutput(
            self, "DeploymentManifest",
            value=json.dumps(deployment_manifest),
            description="Kubernetes deployment manifest for prod-hello"
        )
        
        CfnOutput(
            self, "ServiceManifest",
            value=json.dumps(service_manifest),
            description="Kubernetes service manifest for prod-hello"
        )
        
        # Store cluster name for kubectl commands
        CfnOutput(
            self, "ClusterName",
            value=cluster_name,
            description="EKS Cluster name for kubectl configuration"
        )
        
        CfnOutput(
            self, "KubectlCommands",
            value=f"aws eks update-kubeconfig --name {cluster_name} --region us-east-1",
            description="Command to configure kubectl"
        )
