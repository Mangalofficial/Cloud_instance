provider "aws" {
  region = "ap-east-1"
  profile = "manglam"
}

resource "aws_security_group" "my_security1" {
  name        = "my_security1"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "vpc-c99987a1"

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security"
  }
}


resource "aws_instance" "myinstance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "AWS-key"
  security_groups = ["my_security1"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/mangl/Downloads/AWS-key.pem")
    host     = aws_instance.myin.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "Manglam-OS-1"
  }
}

resource "null_resource" "image"{
  provisioner "local-exec" {
    command = "git clone https://github.com/Mangalofficial/Cloud_instance.git images"
  }
}

resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.myin.availability_zone
  size = 1
  tags = {
    Name = "myebs1"
  }
}

resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.myin.id
  force_detach = true
}

output "myos_ip" {
  value = aws_instance.myin.public_ip
}


resource "null_resource" "nulllocal2"  {
  provisioner "local-exec" {
      command = "echo  ${aws_instance.myin.public_ip} > publicip.txt"
    }
}


resource "aws_s3_bucket" "mybucket" {
  bucket = "manglam420"
  acl    = "public-read"
  region = "ap-east-1"
  tags = {
    Name = "manglam_bucket420"
  }
}
locals {
  s3_origin_id = "s3_origin"
}

resource "aws_s3_bucket_object" "object"{
  depends_on = [aws_s3_bucket.mybucket,null_resource.image]
  bucket = aws_s3_bucket.mybucket.bucket
  acl = "public-read"
  key = "sample.png"
  source = "C:/Users/mangl/Desktop/terraform/mytest/images/sample.png"
  
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  
  enabled = true
  default_root_object = "sample.png"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate for the service.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullremote3" {
  depends_on = [aws_volume_attachment.ebs_attachment,aws_instance.myin]
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/mangl/Downloads/AWS-key.pem")
    host = aws_instance.myin.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Mangalofficial/Cloud_instance.git /var/www/html/",
      "sudo su << EOF",
            "echo \"<img src=\"https://\"${aws_cloudfront_distribution.s3_distribution.domain_name}\"/sample.png\">\" >> /var/www/html/index.html",
            "EOF",
      "sudo systemctl restart httpd",      
    ]
  }
}

resource "null_resource" "nulllocal1"  {
  depends_on = [
    null_resource.nullremote3,
  ]

  provisioner "local-exec" {
    command = "start chrome  ${aws_instance.myin.public_ip}"
  }
}
