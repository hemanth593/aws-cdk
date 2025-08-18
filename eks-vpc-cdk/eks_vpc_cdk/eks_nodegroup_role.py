from aws_cdk import (
    Stack,
    aws_iam as iam,
    CfnOutput
)
from constructs import Construct

class EksNodeGroupRoleStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create the EKS Cluster Role
        self.role = iam.Role(
            self, "EksNodeGroupRole",
            role_name="prod-sre-workernode-role",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com")
        )

        # Add managed policies
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEC2ContainerRegistryReadOnly")
        )
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEKS_CNI_Policy")
        )
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEKSWorkerNodePolicy")          
        )
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")
        )
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMPatchAssociation")
        )
        # First inline policy for WAF
        iam.Policy(
            self, "AllowWAFpolicy",
            policy_name="AllowWAF",
            roles=[self.role],
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "wafv2:AssociateWebACL",
                        "wafv2:DisassociateWebACL",
                        "wafv2:GetWebACL"
                    ],
                    resources=["*"]
                )
            ]
        )

        # Second inline policy for EC2 Tags
        iam.Policy(
            self, "EC2TagsPolicy",
            policy_name="EC2Tags",
            roles=[self.role],
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "ec2:DescribeInstances",
                        "ec2:CreateTags",
                        "ec2:DescribeTags"
                    ],
                    resources=["*"]
                )
            ]
        )

	# Third inline policy for GetCW metrics
        iam.Policy(
            self, "GetCloudwatchMetricsPolicy",
            policy_name="GetCloudwatchMetrics-for-EKS",
            roles=[self.role],
            statements=[
                iam.PolicyStatement(
                    effect=iam.Effect.ALLOW,
                    actions=[
                        "cloudwatch:GetMetricData",
                        "cloudwatch:ListMetrics"
                    ],
                    resources=["*"]
                )
            ]
        )
        # Single output for the role ARN
        CfnOutput(self, "EksNodeGroupRoleArn", value=self.role.role_arn)
