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
@pytest.mark.parametrize(
    "redirect_to,expected_root,expected_path,expected_deep_path",
    [
        # a) hostname only - preserves all paths
        (
            "infrahouse.com",
            "https://infrahouse.com/",
            "https://infrahouse.com/test/path",
            "https://infrahouse.com/deep/nested/path/structure",
        ),
        # b) hostname with path - prepends path to all requests
        (
            "infrahouse.com/some-path",
            "https://infrahouse.com/some-path/",
            "https://infrahouse.com/some-path/test/path",
            "https://infrahouse.com/some-path/deep/nested/path/structure",
        ),
    ],
    ids=["hostname", "path"],
)
def test_module(
    subzone,
    test_role_arn,
    keep_after,
    aws_region,
    boto3_session,
    aws_provider_version,
    redirect_to,
    expected_root,
    expected_path,
    expected_deep_path,
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
                    redirect_to  = "{redirect_to}"
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

        LOG.info(f"Testing redirect_to={redirect_to}")
        LOG.info("=" * 70)

        # Add timestamp for cache-busting to avoid CloudFront caching between tests
        import time

        cache_bust = f"cachebust={int(time.time() * 1000)}"

        # Test 1: HTTP to HTTPS redirect (always redirects to HTTPS version of source)
        source_url = f"http://{zone_name}?{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        # Location should redirect to HTTPS with cache-bust param preserved
        assert response.headers["Location"].startswith(f"https://{zone_name}/")
        assert cache_bust in response.headers["Location"]
        LOG.info(f"✓ {source_url} → {response.headers['Location']}")

        # Test 2: Root path redirect
        LOG.info("Testing root path redirect...")
        source_url = f"https://{zone_name}/?{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        # Check that the path part matches (ignoring cache-bust query param)
        location_without_query = response.headers["Location"].split("?")[0]
        expected_without_query = expected_root.rstrip("?")
        assert (
            location_without_query == expected_without_query
        ), f"Expected {expected_without_query}, got {location_without_query}"
        LOG.info(f"✓ {source_url} → {response.headers['Location']}")

        # Test 3: Path preservation
        LOG.info("Testing path preservation...")
        source_url = f"https://{zone_name}/test/path?{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        location_path = response.headers["Location"].split("?")[0]
        assert (
            location_path == expected_path
        ), f"Expected {expected_path}, got {location_path}"
        LOG.info(f"✓ {source_url} → {response.headers['Location']}")

        # Test 4: Deep path preservation
        LOG.info("Testing deep path preservation...")
        source_url = f"https://{zone_name}/deep/nested/path/structure?{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        location_path = response.headers["Location"].split("?")[0]
        assert (
            location_path == expected_deep_path
        ), f"Expected {expected_deep_path}, got {location_path}"
        LOG.info(f"✓ {source_url} → {response.headers['Location']}")

        # Test 5: Query string preservation (with source query params)
        LOG.info("Testing query string preservation...")
        source_url = f"https://{zone_name}/page?foo=bar&baz=qux&{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        location = response.headers["Location"]
        # Extract redirect_to hostname and path for assertion
        redirect_base = expected_path.replace("/test/path", "")
        expected_query_path = f"{redirect_base}/page"
        assert "foo=bar" in location, f"Query parameter 'foo' not in {location}"
        assert "baz=qux" in location, f"Query parameter 'baz' not in {location}"
        assert (
            expected_query_path in location
        ), f"Path '{expected_query_path}' not in {location}"
        LOG.info(f"✓ {source_url} → {location}")

        # Test 6: Path and query string together
        LOG.info("Testing path + query string preservation...")
        source_url = f"https://{zone_name}/test/path?param1=value1&param2=value2&{cache_bust}"
        response = get(source_url, allow_redirects=False)
        assert response.status_code == 301
        location = response.headers["Location"]
        assert expected_path in location, f"Path '{expected_path}' not in {location}"
        assert "param1=value1" in location
        assert "param2=value2" in location
        LOG.info(f"✓ {source_url} → {location}")

        LOG.info("=" * 70)
        LOG.info("All redirect tests PASSED!")
