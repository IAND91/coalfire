output "apache_url" {
  description = "The URL for the standard Apache web server."
  value       = "http://${module.app_alb.dns_name}"
}

output "docker_2048_url" {
  description = "The URL for the Docker-hosted 2048 game."
  value       = "http://${module.app_alb.dns_name}:8080"
}