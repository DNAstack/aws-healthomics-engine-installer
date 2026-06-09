data "aws_vpc" "this" {
  count = var.enable_vpc_networking ? 1 : 0
  id    = var.vpc_id

  lifecycle {
    precondition {
      condition     = !var.enable_vpc_networking || var.vpc_id != null
      error_message = "vpc_id must be set when enable_vpc_networking is true."
    }
  }
}

locals {
  # Base interface endpoints every VPC-connected run needs: image pull (ecr.api/ecr.dkr)
  # and logging (logs). S3 uses the gateway endpoint below. There is no plain
  # "omics" interface endpoint — HealthOmics PrivateLink services are workflows-omics,
  # storage-omics, control-storage-omics, analytics-omics, tags-omics. The run ENIs
  # don't call the HealthOmics control plane (Workbench/Wallet does that from outside
  # the VPC), so those are added per-env via var.additional_interface_endpoints only
  # when bioinformatics confirms a workflow reaches HealthOmics Storage/APIs in-VPC.
  interface_endpoint_services = var.enable_vpc_networking ? setunion(
    toset(["ecr.api", "ecr.dkr", "logs"]),
    var.additional_interface_endpoints,
  ) : toset([])
}

# SG for the interface VPC endpoints: allow 443 from within the VPC.
resource "aws_security_group" "omics_endpoints" {
  count       = var.enable_vpc_networking ? 1 : 0
  name        = "${var.project_name}-omics-endpoints"
  description = "HTTPS from VPC to HealthOmics interface VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this[0].cidr_block]
  }

  tags = { created_by = "terraform" }
}

# SG attached to the HealthOmics run ENIs (egress-only, least privilege).
resource "aws_security_group" "omics_egress" {
  count       = var.enable_vpc_networking ? 1 : 0
  name        = "${var.project_name}-omics-egress"
  description = "Egress for HealthOmics workflow ENIs"
  vpc_id      = var.vpc_id

  dynamic "egress" {
    for_each = length(var.omics_egress_cidrs) > 0 ? [1] : []
    content {
      description = "HTTPS to approved external endpoints (e.g. Passport) via NAT"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.omics_egress_cidrs
    }
  }

  egress {
    description = "HTTPS to in-VPC interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this[0].cidr_block]
  }

  # S3 reached via the gateway endpoint resolves to S3's public IPs (the managed
  # prefix list), so a restrictive egress SG must explicitly allow it — otherwise
  # the output bucket and any us-east-1 input buckets are blocked at runtime.
  egress {
    description     = "HTTPS to S3 via gateway endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3[0].prefix_list_id]
  }

  egress {
    description = "DNS (UDP) to VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.this[0].cidr_block]
  }

  egress {
    description = "DNS (TCP) to VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this[0].cidr_block]
  }

  tags = { created_by = "terraform" }
}

# S3 gateway endpoint — keeps S3 traffic off the NAT.
resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_vpc_networking ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    created_by = "terraform"
    Name       = "${var.project_name}-s3"
  }
}

# Interface endpoints (ECR api/dkr, CloudWatch Logs, HealthOmics, + extras).
resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_endpoint_services
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.omics_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    created_by = "terraform"
    Name       = "${var.project_name}-${each.value}"
  }
}
