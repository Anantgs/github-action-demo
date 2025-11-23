# Define local values in terraform
locals {
  owners      = var.business_devision
  environment = var.environment
  name        = "${var.business_devision}-${var.environment}"
  common_tag = {
    owners      = local.owners
    environment = local.environment
  }
}
