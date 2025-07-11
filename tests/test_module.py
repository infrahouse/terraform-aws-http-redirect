import json
from os import path as osp
from pprint import pprint
from textwrap import dedent
from time import sleep

from infrahouse_core.aws import get_client
from pytest_infrahouse import terraform_apply
from requests import get

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


def test_module(
    test_role_arn,
    keep_after,
    aws_region,
    test_zone_name,
):

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "main")
    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                    region         = "{aws_region}"
                    test_zone_name = "{test_zone_name}"
                    """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                    role_arn        = "{test_role_arn}"
                    """
                )
            )

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info("%s", json.dumps(tf_output, indent=4))
        response = get(f"http://{test_zone_name}", allow_redirects=False)
        assert response.status_code == 301
        assert response.headers["Location"] == f"https://{test_zone_name}/"

        response = get(f"https://{test_zone_name}", allow_redirects=False)
        assert response.status_code == 301
        assert response.headers["Location"] == f"https://infrahouse.com/"
