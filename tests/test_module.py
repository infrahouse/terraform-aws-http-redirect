import json
from os import path as osp
from pprint import pprint
from textwrap import dedent
from time import sleep

import pytest
from infrahouse_core.aws import get_client
from pytest_infrahouse import terraform_apply
from requests import get

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
    update_terraform_tf,
    cleanup_dot_terraform,
)


@pytest.mark.parametrize(
    "aws_provider_version", ["~> 5.56", "~> 6.0"], ids=["aws-5", "aws-6"]
)
def test_module(
    subzone,
    test_role_arn,
    keep_after,
    aws_region,
    boto3_session,
    aws_provider_version,
):
    # Get zone ID from subzone fixture
    zone_id = subzone["subzone_id"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "main")
    cleanup_dot_terraform(terraform_module_dir)
    update_terraform_tf(terraform_module_dir, aws_provider_version)

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                    region       = "{aws_region}"
                    test_zone_id = "{zone_id}"
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
        LOG.info("%s", json.dumps(tf_output, indent=4))
        zone_name = tf_output["zone_name"]["value"]
        response = get(f"http://{zone_name}", allow_redirects=False)
        assert response.status_code == 301
        assert response.headers["Location"] == f"https://{zone_name}/"

        response = get(f"https://{zone_name}", allow_redirects=False)
        assert response.status_code == 301
        assert response.headers["Location"] == f"https://infrahouse.com/"
