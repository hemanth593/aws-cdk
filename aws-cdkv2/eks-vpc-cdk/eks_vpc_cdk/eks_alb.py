from aws_cdk import (
    Stack,
    aws_elasticloadbalancingv2 as elbv2,
    aws_ec2 as ec2,
    CfnOutput
)
from constructs import Construct
from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack

class EksAlbStack(Stack):
    def __init__(self, scope: Construct, id: str, 
                 vpc_stack: EksVpcCdkStack,
                 **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Import VPC
        vpc_cfn = vpc_stack.vpc
        vpc = ec2.Vpc.from_vpc_attributes(
            self, "ImportedVpc",
            vpc_id=vpc_cfn.ref,
            availability_zones=["us-east-1a", "us-east-1b", "us-east-1c"],
            vpc_cidr_block="192.168.0.0/16"
        )
        
        # Get private subnet IDs for the internal ALB
        private_subnet_ids = [subnet.ref for subnet in vpc_stack.private_subnets]
        
        # Create security group for the ALB
        alb_sg = ec2.SecurityGroup(
            self, "AlbSecurityGroup",
            vpc=vpc,
            security_group_name="prod-eks-sre-hello-alb-sg",
            description="Security group for prod-eks-sre-hello internal ALB",
            allow_all_outbound=True
        )
        
        # Allow HTTP traffic from within VPC
        alb_sg.add_ingress_rule(
            peer=ec2.Peer.ipv4("192.168.0.0/16"),
            connection=ec2.Port.tcp(80),
            description="Allow HTTP from VPC"
        )
        
        # Create the internal Application Load Balancer
        alb = elbv2.CfnLoadBalancer(
            self, "ProdHelloAlb",
            name="prod-eks-sre-hello-alb",
            type="application",
            scheme="internal",  # Internal ALB
            subnets=private_subnet_ids,
            security_groups=[alb_sg.security_group_id],
            ip_address_type="ipv4",
            tags=[
                {"key": "Name", "value": "prod-eks-sre-hello-alb"},
                {"key": "Environment", "value": "prod"},
                {"key": "System", "value": "prod-eks"}
            ]
        )
        
        # Create target group
        target_group = elbv2.CfnTargetGroup(
            self, "ProdHelloTargetGroup",
            name="prod-hello-tg",
            port=80,
            protocol="HTTP",
            vpc_id=vpc_cfn.ref,
            target_type="ip",  # Using IP target type for EKS pods
            health_check_enabled=True,
            health_check_interval_seconds=30,
            health_check_path="/",
            health_check_protocol="HTTP",
            health_check_timeout_seconds=5,
            healthy_threshold_count=2,
            unhealthy_threshold_count=2,
            tags=[
                {"key": "Name", "value": "prod-hello-tg"},
                {"key": "Environment", "value": "prod"}
            ]
        )
        
        # Create listener
        listener = elbv2.CfnListener(
            self, "ProdHelloListener",
            load_balancer_arn=alb.ref,
            port=80,
            protocol="HTTP",
            default_actions=[
                {
                    "type": "forward",
                    "targetGroupArn": target_group.ref
                }
            ]
        )
        
        # Store references
        self.alb = alb
        self.alb_sg = alb_sg
        self.target_group = target_group
        
        # Outputs
        CfnOutput(
            self, "AlbArn",
            value=alb.ref,
            description="ARN of the internal ALB"
        )
        
        CfnOutput(
            self, "AlbDnsName",
            value=alb.attr_dns_name,
            description="DNS name of the internal ALB"
        )
        
        CfnOutput(
            self, "AlbSecurityGroupId",
            value=alb_sg.security_group_id,
            description="Security Group ID for the ALB"
        )
        
        CfnOutput(
            self, "TargetGroupArn",
            value=target_group.ref,
            description="ARN of the target group"
        )
        
        CfnOutput(
            self, "CurlCommand",
            value=f"curl http://{alb.attr_dns_name}",
            description="Command to test the ALB endpoint"
        )
