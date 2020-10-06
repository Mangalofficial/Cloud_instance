# Kubernetes Provider

provider "kubernetes" {
 config_context_cluster = "minikube"
} 

# AWS Provider

provider "aws" {
  region                  = "ap-south-1"
  profile                 = "manglam"
}

# Getting default VPC

data "aws_vpc" "default_vpc" {
    default = true
}

# Getting default Subnets

data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
}


# Security Group for RDS Instance

resource "aws_security_group" "My_security" {
  name        = "rds security group"
  vpc_id      = data.aws_vpc.default_vpc.id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS-SGroup"
  }
}

# Subnet Group for RDS

resource "aws_db_subnet_group" "subnet_grp" {
  name       = "rds subnet group"
  subnet_ids = data.aws_subnet_ids.default_subnet.ids
}

# Configuring Kubernetes Cluster

resource "null_resource" "minikube"  {
  provisioner "local-exec" {
      command = "minikube start"
    }
}

# RDS Instance

resource "aws_db_instance" "RDS_instance" {

    depends_on = [
      aws_security_group.My_security,
      aws_db_subnet_group.subnet_grp,
  ]

  engine                 = "mysql"
  engine_version         = "5.7"
  identifier             = "wpdatabase"
  username               = "wpuser"
  password               = "WordPressPass"
  instance_class         = "db.t2.micro"
  storage_type           = "gp2"
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.subnet_grp.id
  vpc_security_group_ids = [aws_security_group.My_security.id]
  publicly_accessible    = true
  name                   = "WPDatabase"
  parameter_group_name   = "default.mysql5.7"
  iam_database_authentication_enabled = true
  skip_final_snapshot    = true
  
  tags = {
    Name = "rds_db_instance"
  }
}

# Kubernetes Deployment of WordPress

resource "kubernetes_deployment" "WPD" {
  depends_on = [
    null_resource.minikube,
  ]
  metadata {  
    name = "wordpress"  
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        env = "production"
    region = "IN"
    App = "wordpress"
      }
    match_expressions {
    key = "env"
    operator = "In"
    values = ["production","webserver"]
    }
  }
    template {
      metadata {
        labels = {
      env = "production"
      region = "IN"
      App = "wordpress"
        }
      }
      spec {
        container {
          image = "wordpress:4.8-apache"
          name  = "wordpress"
        }
      }
    }
  }
}

# Exposing Kubernetes Deployment

resource "kubernetes_service" "NodePort" {  
  depends_on = [
    kubernetes_deployment.WPD,
  ]
  metadata {
    name = "wordpress"
  }
  spec {
    selector = {
      App = "wordpress"
    }
    port {
      protocol = "TCP"
      port = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

resource "null_resource" "service"  {
  depends_on = [
    kubernetes_service.NodePort,
    aws_db_instance.RDS_instance,
  ]
  provisioner "local-exec" {
      command = "minikube service wordpress"
    }
}

output "RDS_Instance_IP" {
  value = aws_db_instance.RDS_instance.address
}
