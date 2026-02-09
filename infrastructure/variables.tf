variable "region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "The name of the VPC and prefix for associated resources."
  type        = string
  default     = "coalfire-web-vpc"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "admin_ip" {
  description = "The public IP address allowed to SSH into the bastion host (CIDR notation)."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance size for both bastion and application hosts."
  type        = string
  default     = "t2.micro"
}

variable "app_instance_count" {
  description = "The number of application server instances to deploy."
  type        = number
  default     = 2
}