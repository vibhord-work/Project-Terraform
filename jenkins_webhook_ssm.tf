resource "aws_ssm_document" "jenkins_webhook_trigger" {
  name            = "${var.project_name}-${var.environment}-jenkins-webhook-trigger"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Trigger the Hospital ECS Jenkins pipeline"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "triggerJenkins"
        inputs = {
          runCommand = [
            "set -eu",
            "SECRET=$(aws secretsmanager get-secret-value --secret-id project/poc/jenkins-webhook-credentials --region us-east-1 --query SecretString --output text)",
            "export SECRET",
            "python3 - <<'PY'",
            "import base64, json, os, urllib.request",
            "credentials = json.loads(os.environ['SECRET'])",
            "url = 'http://127.0.0.1:8080/job/hospital-ecs-cicd/build'",
            "auth = base64.b64encode((credentials['username'] + ':' + credentials['token']).encode()).decode()",
            "request = urllib.request.Request(url, data=b'', method='POST', headers={'Authorization': 'Basic ' + auth})",
            "with urllib.request.urlopen(request, timeout=15) as response:",
            "    print('Jenkins build trigger HTTP:', response.status)",
            "PY",
            "unset SECRET"
          ]
        }
      }
    ]
  })
}
