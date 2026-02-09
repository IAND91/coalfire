module "web_server_vpc" {
  source = "git::https://github.com/Coalfire-CF/terraform-aws-vpc-nfw.git?ref=v3.1.0"

  vpc_name = var.vpc_name
  cidr     = var.vpc_cidr
  azs      = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]

  map_public_ip_on_launch = true

  subnets = [
    {
      tag               = "management"
      cidr              = cidrsubnet(var.vpc_cidr, 8, 1)
      type              = "public"
      availability_zone = data.aws_availability_zones.available.names[0]
    },
    {
      tag               = "management-secondary"
      cidr              = cidrsubnet(var.vpc_cidr, 8, 11)
      type              = "public"
      availability_zone = data.aws_availability_zones.available.names[1]
    },
    {
      tag               = "application"
      cidr              = cidrsubnet(var.vpc_cidr, 8, 2)
      type              = "private"
      availability_zone = data.aws_availability_zones.available.names[0]
    }
  ]

  single_nat_gateway   = true
  enable_nat_gateway   = true
  enable_dns_hostnames = true
  flow_log_destination_type = "cloud-watch-logs"
}

module "management_ec2" {
  source = "github.com/Coalfire-CF/terraform-aws-ec2?ref=v1.0.8"

  name                = "${var.vpc_name}-bastion"
  ec2_instance_type   = var.instance_type
  instance_count      = 1
  ami                 = data.aws_ami.linux.id
  vpc_id              = module.web_server_vpc.vpc_id
  subnet_ids          = [values(module.web_server_vpc.public_subnets)[0]]
  ec2_key_pair        = aws_key_pair.deployer_key.key_name
  associate_public_ip = true

  ingress_rules = {
    "ssh_from_admin" = {
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = var.admin_ip
    }
  }
  egress_rules = { "allow_all" = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" } }
  ebs_kms_key_arn  = null
  global_tags = {}
  root_volume_size = 50
}

module "app_ec2" {
  source = "github.com/Coalfire-CF/terraform-aws-ec2?ref=v1.0.8"

  name              = "${var.vpc_name}-app-host"
  ec2_instance_type = var.instance_type
  instance_count    = var.app_instance_count
  ami               = data.aws_ami.linux.id
  vpc_id            = module.web_server_vpc.vpc_id
  subnet_ids        = [values(module.web_server_vpc.private_subnets)[0]]
  ec2_key_pair      = aws_key_pair.deployer_key.key_name

  user_data = base64encode(templatefile("${path.module}/setup.sh", {}))

  ingress_rules = {
    "ssh_from_bastion" = {
      ip_protocol                  = "tcp"
      from_port                    = 22
      to_port                      = 22
      referenced_security_group_id = module.management_ec2.sg_id
    },
    "alb_80" = {
      ip_protocol                  = "tcp"
      from_port                    = 80
      to_port                      = 80
      referenced_security_group_id = module.app_alb.security_group_id
    },
    "alb_8080" = {
      ip_protocol                  = "tcp"
      from_port                    = 8080
      to_port                      = 8080
      referenced_security_group_id = module.app_alb.security_group_id
    }
  }
  egress_rules = { "allow_all" = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" } }
  ebs_kms_key_arn  = null
  global_tags = {}
  root_volume_size = 50
}

module "app_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.17.0"

  name    = "${var.vpc_name}-alb"
  vpc_id  = module.web_server_vpc.vpc_id
  subnets = values(module.web_server_vpc.public_subnets)

  security_group_ingress_rules = {
    all_http = { from_port = 80, to_port = 80, ip_protocol = "tcp", cidr_ipv4 = "0.0.0.0/0" }
    all_8080 = { from_port = 8080, to_port = 8080, ip_protocol = "tcp", cidr_ipv4 = "0.0.0.0/0" }
  }
  security_group_egress_rules = {
    all_traffic = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  }

  listeners = {
    http      = { port = 80, protocol = "HTTP", forward = { target_group_key = "app-tg" } }
    http_8080 = { port = 8080, protocol = "HTTP", forward = { target_group_key = "docker-tg" } }
  }

  target_groups = {
    app-tg = {
      name_prefix = "app-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"
      create_attachment = false
      health_check = { path = "/", matcher = "200-403" }
    }
    docker-tg = {
      name_prefix = "dock-"
      protocol    = "HTTP"
      port        = 8080
      target_type = "instance"
      create_attachment = false
      health_check = {
        path = "/",
        port = "8080",
        matcher = "200-399"
      }
    }
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.app_instance_count
  target_group_arn = module.app_alb.target_groups["app-tg"].arn
  target_id        = module.app_ec2.instance_id[count.index]
  port             = 80
}

resource "aws_lb_target_group_attachment" "docker" {
  count            = var.app_instance_count
  target_group_arn = module.app_alb.target_groups["docker-tg"].arn
  target_id        = module.app_ec2.instance_id[count.index]
  port             = 8080
}

resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "ian-key-${sha1(tls_private_key.generated_key.public_key_openssh)}"
  public_key = tls_private_key.generated_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.generated_key.private_key_pem
  filename        = "${path.module}/ian-key.pem"
  file_permission = "0600"
}