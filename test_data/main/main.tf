module "test" {
  source             = "./../../"
  redirect_to        = "infrahouse.com"
  redirect_hostnames = ["", "foo", "bar"]
  zone_id            = var.test_zone_id
}
