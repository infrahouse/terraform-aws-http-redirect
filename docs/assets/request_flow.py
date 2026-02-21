#!/usr/bin/env python3
"""
Generate request flow diagram for terraform-aws-http-redirect module.

Requirements:
    pip install diagrams

Usage:
    python request_flow.py

Output:
    request_flow.png (in current directory)
"""
from diagrams import Diagram, Edge
from diagrams.aws.network import CloudFront, Route53
from diagrams.aws.storage import S3
from diagrams.onprem.client import Users

fontsize = "14"

graph_attr = {
    "splines": "spline",
    "nodesep": "0.8",
    "ranksep": "0.8",
    "fontsize": fontsize,
    "fontname": "Roboto",
    "dpi": "150",
}

node_attr = {
    "fontname": "Roboto",
    "fontsize": fontsize,
}

edge_attr = {
    "fontname": "Roboto",
    "fontsize": "12",
}

with Diagram(
    "Request Flow",
    filename="request_flow",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat="png",
):
    user = Users("User")
    route53 = Route53("Route 53")
    cloudfront = CloudFront("CloudFront")
    s3 = S3("S3")
    target = Users("Target\nDomain")

    # Forward flow
    user >> Edge(label="1. Request", color="darkgreen") >> route53
    route53 >> Edge(label="2. DNS", color="blue") >> cloudfront
    cloudfront >> Edge(label="3. Origin", color="blue") >> s3

    # Return flow
    s3 >> Edge(label="4. HTTP 301", color="orange") >> cloudfront
    cloudfront >> Edge(label="5. Redirect", color="orange") >> user

    # Follow redirect
    user >> Edge(label="6. Follow", color="purple", style="dashed") >> target
