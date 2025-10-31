from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_create_cluster import EksClusterStack
import base64

class EksLaunchTemplateStack(Stack):
    def __init__(self, scope: Construct, id: str, eks_cluster_stack: EksClusterStack, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Get the primary security group ID from the EKS cluster
        primary_sg_id = eks_cluster_stack.primary_security_group_id
        
        # Define the key pair name (change this to your actual key pair name)
        key_pair_name = "prod-eks-sre"
        
        # User data script for EKS worker nodes
        # This is the standard EKS-optimized AMI bootstrap script
        user_data_script = f"""#!/bin/bash
Content-Type: multipart/mixed; boundary="==BOUNDARY=="

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

# Copyright (C) 2025 Hemanth Pagidimarri <pagidh@amazon.com>
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.

INSTANCE_ID=`curl -sL http://169.254.169.254/latest/meta-data/instance-id`
REGION=`curl -sL http://169.254.169.254/latest/meta-data/placement/region`
PREFIX="prod-eks-scheduler"
TIMESTAMP=$(($(date +"%s%N")/1000000))
SET_HOSTNAME="$PREFIX-$TIMESTAMP"

aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags "Key"="Name",Value="$SET_HOSTNAME"

--==BOUNDARY==--
"""
        
        # Encode user data to base64 (as expected by launch template)
        user_data_encoded = base64.b64encode(user_data_script.encode()).decode()

        # Create the launch template
        launch_template = ec2.CfnLaunchTemplate(
            self, "ProdSchedulerLaunchTemplate",
            launch_template_name="prod-scheduler-v2-lt",
            launch_template_data=ec2.CfnLaunchTemplate.LaunchTemplateDataProperty(
                # Key pair for SSH access
                key_name=key_pair_name,
                
                # Instance type
                instance_type="t3a.xlarge",
                
                # User data script (base64 encoded)
                user_data=user_data_encoded,
                
                # Metadata options
                metadata_options=ec2.CfnLaunchTemplate.MetadataOptionsProperty(
                    http_endpoint="enabled",
                    instance_metadata_tags="enabled"
                ),
                
                # Tag specifications for instances launched from this template
                tag_specifications=[
                    ec2.CfnLaunchTemplate.TagSpecificationProperty(
                        resource_type="instance",
                        tags=[
                            {"key": "Environment", "value": "prod"},
                            {"key": "System", "value": "prod-eks"},
                            {"key": "Component", "value": "prod-eks-scheduler"}
                        ]
                    )
                ],
                
                # Network interfaces configuration
                network_interfaces=[
                    ec2.CfnLaunchTemplate.NetworkInterfaceProperty(
                        device_index=0,
                        groups=[primary_sg_id]  # Use the primary security group from EKS cluster
                    )
                ],
                
                # Block device mappings (EBS volume configuration)
                block_device_mappings=[
                    ec2.CfnLaunchTemplate.BlockDeviceMappingProperty(
                        device_name="/dev/xvda",
                        ebs=ec2.CfnLaunchTemplate.EbsProperty(
                            delete_on_termination=True,
                            iops=3000,
                            volume_size=70,
                            volume_type="gp3",
                            throughput=125
                        )
                    )
                ]
            )
        )

        # Store the launch template for potential use by other stacks
        self.launch_template = launch_template

        # Outputs
        CfnOutput(
            self, "LaunchTemplateId", 
            value=launch_template.ref,
            description="Launch Template ID for EKS node group"
        )
        
        CfnOutput(
            self, "LaunchTemplateName", 
            value=launch_template.launch_template_name,
            description="Launch Template Name"
        )
        
        CfnOutput(
            self, "UsedSecurityGroupId", 
            value=primary_sg_id,
            description="Primary security group ID from EKS cluster used in launch template"
        )
