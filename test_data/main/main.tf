module "test" {
  source             = "./../../"
  redirect_to        = "infrahouse.com"
  redirect_hostnames = ["", "foo", "bar"]
  zone_id            = data.aws_route53_zone.test-zone.zone_id
}
