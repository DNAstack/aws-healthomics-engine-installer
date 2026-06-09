resource "awscc_omics_configuration" "this" {
  count       = var.enable_vpc_networking ? 1 : 0
  name        = coalesce(var.configuration_name, "${var.project_name}-vpc")
  description = "VPC-connected networking configuration for ${var.project_name} HealthOmics runs"

  run_configurations = {
    vpc_config = {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.omics_egress[0].id]
    }
  }

  tags = {
    created_by = "terraform"
  }
}
