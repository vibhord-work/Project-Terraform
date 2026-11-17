
variable "ecs_cluster_name" {
  type    = string
  default = "project-poc-ecs-cluster"
}

variable "frontend_service_name" {
  type    = string
  default = "project-poc-frontend-service"
}

variable "backend_service_name" {
  type    = string
  default = "project-poc-backend-service"
}

variable "rds_identifier" {
  type = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "frontend_target_group_arn_suffix" {
  type = string
}

variable "backend_target_group_arn_suffix" {
  type = string
}

resource "aws_cloudwatch_dashboard" "project_health" {
  dashboard_name = "project-poc-health-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS CPU Utilization"
          region = var.aws_region
          period = 300
          stat   = "Average"

          metrics = [
            ["AWS/ECS", "CPUUtilization",
              "ClusterName", var.ecs_cluster_name,
            "ServiceName", var.frontend_service_name],
            [".", "CPUUtilization",
              ".", ".",
            ".", var.backend_service_name]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS Memory Utilization"
          region = var.aws_region
          period = 300
          stat   = "Average"

          metrics = [
            ["AWS/ECS", "MemoryUtilization",
              "ClusterName", var.ecs_cluster_name,
            "ServiceName", var.frontend_service_name],
            [".", "MemoryUtilization",
              ".", ".",
            ".", var.backend_service_name]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ECS Running and Pending Tasks"
          region = var.aws_region
          period = 300
          stat   = "Average"

          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount",
              "ClusterName", var.ecs_cluster_name,
            "ServiceName", var.frontend_service_name],
            [".", "RunningTaskCount",
              ".", ".",
            ".", var.backend_service_name],
            [".", "PendingTaskCount",
              ".", ".",
            ".", var.frontend_service_name],
            [".", "PendingTaskCount",
              ".", ".",
            ".", var.backend_service_name]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "RDS Database Health"
          region = var.aws_region
          period = 300
          stat   = "Average"

          metrics = [
            ["AWS/RDS", "CPUUtilization",
            "DBInstanceIdentifier", var.rds_identifier],
            [".", "DatabaseConnections",
            ".", "."]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ALB Healthy / Unhealthy Targets"
          region = var.aws_region
          period = 300
          stat   = "Average"

          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount",
              "LoadBalancer", var.alb_arn_suffix,
            "TargetGroup", var.frontend_target_group_arn_suffix],
            [".", "UnHealthyHostCount",
              ".", ".",
            ".", "."],
            [".", "HealthyHostCount",
              ".", ".",
            "TargetGroup", var.backend_target_group_arn_suffix],
            [".", "UnHealthyHostCount",
              ".", ".",
            ".", "."]
          ]
        }
      }
    ]
  })
}
