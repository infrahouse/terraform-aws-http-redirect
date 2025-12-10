data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "test-zone" {
  zone_id = var.test_zone_id
}
