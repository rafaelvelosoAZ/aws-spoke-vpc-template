resource "aws_vpc" "workload_vpc" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"

  tags = {
    "Name" = "workload-VPC"
  }
}

resource "aws_subnet" "snet_pvt_workload" {
  vpc_id            = aws_vpc.workload_vpc.id
  cidr_block        = "10.1.0.0/24"
  availability_zone = local.zone_a
  tags = {
    "Name" = "snet-workload-pvt"
  }
}

resource "aws_subnet" "snet_pvt_b_workload" {
  vpc_id            = aws_vpc.workload_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = local.zone_a
  tags = {
    "Name" = "snet-workload-b-pvt"
  }
}

resource "aws_route_table" "rt_pvt_snet_workload_vpc" {
  vpc_id = aws_vpc.workload_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    "Name" = "rt-pvt-workload"
  }
}

resource "aws_route_table_association" "snet_rt_pvt_workload" {
  subnet_id      = aws_subnet.snet_pvt_workload.id
  route_table_id = aws_route_table.rt_pvt_snet_workload_vpc.id
}

####################### ec2 ###############################

resource "aws_instance" "vm_workload" {
  ami           = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.sg_workload.id]

  subnet_id = aws_subnet.snet_pvt_workload.id

  tags = {
    "Name" = "vm-workload"
  }
}

resource "aws_security_group" "sg_workload" {
  name_prefix = "allow-all-traffic"

  vpc_id = aws_vpc.workload_vpc.id 
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
    ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    "Name" = "SG-workload"
  }
}