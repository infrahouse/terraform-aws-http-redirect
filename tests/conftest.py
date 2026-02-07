import json
import logging
import shutil
from os import path as osp, remove
from textwrap import dedent

import pytest
from infrahouse_core.logging import setup_logging
from pytest_infrahouse import terraform_apply

DEFAULT_PROGRESS_INTERVAL = 10
TERRAFORM_ROOT_DIR = "test_data"


LOG = logging.getLogger(__name__)


setup_logging(LOG, debug=True)


@pytest.fixture(scope="function")
def shared_certificate(subzone, test_role_arn, aws_region, keep_after):
    """
    Create external ACM certificate and DNS records to simulate another module.

    This fixture creates:
    - ACM certificate for the test domain (in user's region, like ECS/website-pod)
    - CAA record
    - Certificate validation CNAME record

    The http-redirect module test will then use create_certificate_dns_records=false
    to avoid conflicts with these existing records.
    """
    zone_id = subzone["subzone_id"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "shared_certificate")
    cleanup_dot_terraform(terraform_module_dir)

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region  = "{aws_region}"
                zone_id = "{zone_id}"
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                role_arn = "{test_role_arn}"
                """
                )
            )

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info(
            "shared_certificate fixture created: %s", json.dumps(tf_output, indent=4)
        )
        yield tf_output


def update_terraform_tf(terraform_module_dir, aws_provider_version):
    """Update terraform.tf with specified AWS provider version."""
    terraform_tf_path = osp.join(terraform_module_dir, "terraform.tf")
    with open(terraform_tf_path, "w") as fp:
        fp.write(
            dedent(
                f"""
                terraform {{
                  required_providers {{
                    aws = {{
                      source  = "hashicorp/aws"
                      version = "{aws_provider_version}"
                    }}
                  }}
                }}
                """
            )
        )


def cleanup_dot_terraform(terraform_module_dir):
    """Remove .terraform directory and lock file to force re-initialization."""
    state_files = [
        osp.join(terraform_module_dir, ".terraform"),
        osp.join(terraform_module_dir, ".terraform.lock.hcl"),
    ]

    for state_file in state_files:
        try:
            if osp.isdir(state_file):
                shutil.rmtree(state_file)
            elif osp.isfile(state_file):
                remove(state_file)
        except FileNotFoundError:
            # File was already removed by another process
            pass
