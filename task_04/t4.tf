provider "aws" {
region = "ap-south-1"
profile = "IAMUSER"
}

resource "aws_vpc" "create_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "deepsvpc"
  }
}

resource "aws_subnet" "pub" {
  vpc_id     = "${aws_vpc.create_vpc.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "pub"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.create_vpc.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private"
  }
}
resource "aws_internet_gateway" "deepsigw" {
  vpc_id = "${aws_vpc.create_vpc.id}"

  tags = {
    Name = "deepsigw"
  }
}
resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.create_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.deepsigw.id}"
  }

  
  tags = {
    Name = "route_table"
  }
}


  

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.pub.id
  route_table_id = aws_route_table.route_table.id
}


resource "aws_security_group" "sg_public" {
  name        = "sg_public"
  description = "sg_public"
  vpc_id      = "${aws_vpc.create_vpc.id}"

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
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
    Name = "sg_public"
  }
}

resource "aws_security_group" "sg_private" {
  name        = "sg_private"
  description = "sg_private"
  vpc_id      = "${aws_vpc.create_vpc.id}"

  ingress {
    description = "sg_private"
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "sg_private"
  }
}

resource "aws_eip" "Elastic_ip" {
	vpc	= true
}

#To create NAT Gateway 
resource "aws_nat_gateway" "NAT" {
	allocation_id	= "${aws_eip.Elastic_ip.id}"
	subnet_id	= "${aws_subnet.pub.id}"
	tags = {
		Name = "NAT-GATEWAY"
	}
	depends_on	= [aws_internet_gateway.deepsigw]
}

resource "aws_route_table" "NAT_R_TABLE" {
	vpc_id	= "${aws_vpc.create_vpc.id}"
	route {
		cidr_block	= "0.0.0.0/0"
		nat_gateway_id	= "${aws_nat_gateway.NAT.id}"
	}
	tags = {
		Name = "ROUTETABLEFORNAT"
	}
}

resource "aws_route_table_association" "NAT_TABLE_ASSOCIATE" {
	subnet_id	= "${aws_subnet.private.id}"
	route_table_id	= "${aws_route_table.NAT_R_TABLE.id}"
}

resource "aws_instance" "wordpress" {
  ami = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.pub.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_public.id}"]
  key_name = "newkey"
 tags ={
    Name= "wordpress"
  }
depends_on = [
    aws_route_table_association.public_association,
  ]
}

resource "aws_instance" "mysql" {
  ami = "ami-0019ac6129392a0f2"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private.id}"
  vpc_security_group_ids = ["${aws_security_group.sg_private.id}"]
  key_name = "newkey"
 tags ={
    Name= "mysql"
  }
depends_on = [
    aws_route_table_association.public_association,
  ]
}

output "wordpress_dns" {
  	value = aws_instance.wordpress.public_dns
}

