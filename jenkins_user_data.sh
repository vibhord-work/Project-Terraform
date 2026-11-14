#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y java-21-amazon-corretto docker git awscli

curl -fsSL \
  https://pkg.jenkins.io/redhat-stable/jenkins.repo \
  -o /etc/yum.repos.d/jenkins.repo

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

dnf install -y jenkins

systemctl enable --now docker
systemctl enable --now jenkins

usermod -aG docker jenkins
systemctl restart jenkins
