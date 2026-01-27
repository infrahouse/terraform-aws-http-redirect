#!/usr/bin/env python3
"""
Generate resource dependencies diagram for terraform-aws-http-redirect module.

Requirements:
    pip install diagrams

Usage:
    python dependencies.py

Output:
    dependencies.png (in current directory)
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import Route53
from diagrams.aws.security import ACM
from diagrams.aws.storage import S3
from diagrams.aws.network import CloudFront
from diagrams.custom import Custom

fontsize = "12"

graph_attr = {
    "splines": "ortho",
    "nodesep": "0.6",
    "ranksep": "0.6",
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
    "fontsize": "10",
}

with Diagram(
    "Resource Dependencies",
    filename="dependencies",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat="png",
):
    with Cluster("Data Sources"):
        zone_data = Route53("aws_route53_zone\n(data)")

    with Cluster("ACM Certificate Chain"):
        acm_cert = ACM("aws_acm_certificate")
        cert_validation_record = Route53("aws_route53_record\n(validation)")
        acm_validation = ACM("aws_acm_certificate\n_validation")

    with Cluster("S3 Buckets"):
        s3_bucket = S3("aws_s3_bucket")
        s3_website = S3("aws_s3_bucket\n_website_configuration")
        s3_policy = S3("aws_s3_bucket\n_policy")
        s3_encryption = S3("aws_s3_bucket\n_server_side_encryption")
        s3_logs = S3("module.cloudfront\n_logs_bucket")

    with Cluster("CloudFront"):
        cloudfront = CloudFront("aws_cloudfront\n_distribution")

    with Cluster("DNS Records"):
        dns_records = Route53("aws_route53_record\n(A/AAAA aliases)")

    # ACM chain
    zone_data >> acm_cert
    acm_cert >> cert_validation_record
    cert_validation_record >> acm_validation

    # S3 chain
    zone_data >> s3_bucket
    s3_bucket >> s3_website
    s3_bucket >> s3_policy
    s3_bucket >> s3_encryption

    # CloudFront depends on ACM validation and S3
    acm_validation >> cloudfront
    s3_bucket >> cloudfront
    cloudfront >> s3_logs

    # DNS records depend on CloudFront
    cloudfront >> dns_records