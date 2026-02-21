#!/usr/bin/env python3
"""
Generate architecture diagram for terraform-aws-http-redirect module.

This diagram is generated from analysis of the actual Terraform code.

Requirements:
    pip install diagrams

Usage:
    python architecture.py

Output:
    architecture.png (in current directory)
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import CloudFront, Route53
from diagrams.aws.security import ACM
from diagrams.aws.storage import S3
from diagrams.onprem.client import Users

fontsize = "16"

# Match MkDocs Material theme fonts (Roboto)
# Increase sizes for better readability
graph_attr = {
    "splines": "spline",
    "nodesep": "1.0",
    "ranksep": "1.0",
    "fontsize": fontsize,
    "fontname": "Roboto",
    "dpi": "200",
    "compound": "true",
}

node_attr = {
    "fontname": "Roboto",
    "fontsize": fontsize,
}

edge_attr = {
    "fontname": "Roboto",
    "fontsize": fontsize,
}

with Diagram(
    "HTTP Redirect - AWS Architecture",
    filename="architecture",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat="png",
):
    # External - Users
    users = Users("\nUsers")

    with Cluster("AWS Account"):

        # DNS and Certificate
        with Cluster("DNS & SSL (us-east-1 for ACM)"):
            route53 = Route53("\nRoute53\nA/AAAA Records")
            acm = ACM("\nACM Certificate")

        # CloudFront
        cloudfront = CloudFront("\nCloudFront\nDistribution")

        # S3
        with Cluster("S3 Buckets"):
            s3_redirect = S3("\nRedirect\nBucket")
            s3_logs = S3("\nLogs\nBucket")

    # Target domain (external)
    target = Users("\nTarget Domain\n(redirect destination)")

    # ============ CONNECTIONS ============

    # User traffic flow
    users >> Edge(label="1. HTTPS Request", color="green") >> route53

    # DNS resolution
    route53 >> Edge(label="2. DNS Alias", style="dashed") >> cloudfront

    # SSL Certificate
    acm >> Edge(label="TLS Cert", style="dashed") >> cloudfront

    # CloudFront to S3
    cloudfront >> Edge(label="3. Origin Request", color="blue") >> s3_redirect

    # S3 redirect response
    s3_redirect >> Edge(label="4. HTTP 301", color="orange") >> cloudfront

    # CloudFront to user
    cloudfront >> Edge(label="5. Redirect Response", color="green") >> users

    # User follows redirect
    users >> Edge(label="6. Follow Redirect", color="purple", style="dashed") >> target

    # CloudFront logs to S3
    cloudfront >> Edge(label="Access Logs", style="dotted", color="gray") >> s3_logs
