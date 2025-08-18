import aws_cdk as core
import aws_cdk.assertions as assertions

from eks_vpc_cdk.eks_vpc_cdk_stack import EksVpcCdkStack

# example tests. To run these tests, uncomment this file along with the example
# resource in eks_vpc_cdk/eks_vpc_cdk_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = EksVpcCdkStack(app, "eks-vpc-cdk")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
