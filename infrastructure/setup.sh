#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting setup"

MAX_RETRIES=30
COUNT=0
until ping -c 1 google.com >/dev/null 2>&1 || [ $COUNT -eq $MAX_RETRIES ]; do
  echo "Waiting for internet connectivity..."
  sleep 2
  ((COUNT++))
done

yum update -y
amazon-linux-extras install docker -y
yum install -y httpd

systemctl enable --now docker
systemctl enable --now httpd

echo "<h1>Hello Coalfire!</h1>" > /var/www/html/index.html

if ! docker ps -a | grep -q arcade; then
  docker run -d --name arcade --restart always -p 8080:80 public.ecr.aws/l6m2t8p7/docker-2048:latest
fi

echo "Finished setup"