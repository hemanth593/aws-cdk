from aws_cdk import (
    Stack,
    aws_iam as iam,
    CfnOutput
)
from constructs import Construct

class EksClusterRoleStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create the EKS Cluster Role
        self.role = iam.Role(
            self, "EksClusterRole",
            role_name="prod-sre-eks-cluster-role",
            assumed_by=iam.ServicePrincipal("eks.amazonaws.com")
        )

        # Add managed policies
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEKSClusterPolicy")
        )
        self.role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonEKSVPCResourceController")
        )

        # Create named inline policy
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

        # Output the role ARN
        CfnOutput(self, "EksClusterRoleArn", value=self.role.role_arn)
