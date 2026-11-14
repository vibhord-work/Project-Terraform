resource "aws_dynamodb_table" "github_webhook_deliveries" {
  name         = "${var.project_name}-${var.environment}-github-webhook-deliveries"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "delivery_id"

  attribute {
    name = "delivery_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-github-webhook-deliveries"
  }
}
