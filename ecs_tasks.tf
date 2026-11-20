removed {
  from = aws_ecs_task_definition.frontend

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ecs_task_definition.backend

  lifecycle {
    destroy = false
  }
}
