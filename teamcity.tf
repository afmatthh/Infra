provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.24.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name           = "main"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "main"
  }
}

resource "aws_route" "ipv4-outbound" {
  route_table_id          = "${aws_vpc.main.main_route_table_id}"
  gateway_id              = "${aws_internet_gateway.gw.id}"
  destination_cidr_block  = "0.0.0.0/0"
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["92.33.16.139/32", "94.254.123.168/32","213.64.123.86/32"]
  }

  ingress {
    from_port       = 8111
    to_port         = 8111
    protocol        = "tcp"
    cidr_blocks     = ["92.33.16.139/32", "94.254.123.168/32","213.64.123.86/32"]
  }
}

resource "aws_security_group" "web" {
  vpc_id = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["10.24.1.0/24", "92.33.16.139/32", "94.254.123.168/32","213.64.123.86/32"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "mgmt" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.24.1.0/24"
  map_public_ip_on_launch = "True"

  tags {
    Name            = "Mgmt"
  }
}

resource "aws_subnet" "prod" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.24.8.0/24"
  map_public_ip_on_launch = "True"

  tags {
    Name            = "Prod"
  }
}

resource "aws_instance" "TeamCity" {
  ami                    = "${lookup(var.amis, var.region)}"
  instance_type          = "${lookup(var.size, "teamcity")}"
  key_name               = "${var.aws_keyname}"
  subnet_id              = "${aws_subnet.mgmt.id}"

  provisioner "remote-exec" {
    inline = ["ls"]
    connection {
      host = "${self.public_ip}"
      type = "ssh"
      user = "ec2-user"
      private_key = "${file(var.private_key_file)}"
     }
  }
  provisioner "local-exec" {
    command = "sleep 60;ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=${var.private_key_file} --user=ec2-user -i '${self.public_ip},' ./ansible/teamcity.yml"
  }
}

resource "aws_instance" "ProdWeb" {
  count                  = "2"
  ami                    = "${lookup(var.amis, var.region)}"
  instance_type          = "${lookup(var.size, "web")}"
  key_name               = "${var.aws_keyname}"
  subnet_id              = "${aws_subnet.prod.id}"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]

  provisioner "remote-exec" {
    inline = ["ls"]
    connection {
      host = "${self.public_ip}"
      type = "ssh"
      user = "ec2-user"
      private_key = "${file(var.private_key_file)}"
     }
  }
  provisioner "local-exec" {
    command = "sleep 60;ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key=${var.private_key_file} --user=ec2-user -i '${self.public_ip},' ./ansible/web.yml"
  }
}
