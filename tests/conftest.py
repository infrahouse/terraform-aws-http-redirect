import logging
import shutil
from os import path as osp, remove
from textwrap import dedent

from infrahouse_core.logging import setup_logging

DEFAULT_PROGRESS_INTERVAL = 10
TERRAFORM_ROOT_DIR = "test_data"


LOG = logging.getLogger(__name__)


setup_logging(LOG, debug=True)


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
