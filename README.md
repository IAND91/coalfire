# AWS Application Infrastructure

This repository contains the Terraform configuration for an Apache web server and a dockerized game hosted on AWS.

---

## Overview

The infrastructure follows AWS best practices for network isolation:
* **Public Subnets:** Host the Application Load Balancer (ALB) and a Management Bastion host.
* **Private Subnets:** Host the application tier. Instances have no direct internet ingress but can communicate outbound via a NAT Gateway.
* **Load Balancing:** A single ALB manages two listeners (Port 80 and Port 8080), routing traffic to specific target groups based on the request port.



---

## Deployment Instructions

### Prerequisites
* Terraform `~> 1.5`
* AWS CLI configured with appropriate credentials.
* `git` installed for module sourcing.

### Steps
1.  **Clone the Repository:**
    ```bash
    git clone repo

    ```
2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
3.  **Deployment:**
    ```bash
    terraform plan
    terraform apply
    ```
4.  **Verification:**
    * Access the webpage and docker game via endpoints (found in outputs).

---

## Design Decisions and Assumptions

### Design Decisions
* **AZ's:** For reliability and connectivity with a single NAT gateway, application instances are pinned to the same AZ as the NAT Gateway (`us-east-1a`).
* **Least privilege:** Ingress rules for the application are restricted to the ALB's security group ID rather than open CIDR blocks.
* **Provisioning:** A script handles the automated installation of the `httpd` service and the `docker` engine upon instance launch.

### Assumptions
* **Test Env:** A single NAT Gateway seems sufficient for the this as it will optimize cost over high availability.
* **Access:** SSH access via a Bastion host rather than Session Manager.

---

## Improvement Plan & Priorities

1.  **P1 Multi-AZ NAT Gateways:** Move from single NAT gateway to one per AZ.
2.  **P2 Security:** Use AWS Cert manager to enable HTTPS.
3.  **P3 Auto Scaling:** Implement an ASG to allow scaling based on CPU/Memory demand.
4.  **P4 Remote State:** Migrate terraform.tfstate file to S3 as remote backend.

---

## Analysis of Operational Gaps

* **Logging:** While VPC flow logs are enabled, there is currently no logging for apache or docker.
* **Monitoring:** Lacking cloudwatch alarms for notification of errors.

---

## Evidence of Successful Deployment

* **Infrastructure Build:** Successfully provisioned 24 resources including VPC, NFW, ALB, and EC2.
* **Service Availability:**
    * **Port 80:** Returns "Hello Coalfire!".
    * **Port 8080:** Successfully serves the 2048 game via Docker container.
* **Health Checks:** Both Target Groups (app and docker) show healthy status in the AWS Console.
* Full formatted plan file found [here]()

### Diagram and screenshots

* Found in [Images directory]()

---

## References
* [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [Coalfire-CF GitHub Modules](https://github.com/Coalfire-CF)
* [AWS Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)