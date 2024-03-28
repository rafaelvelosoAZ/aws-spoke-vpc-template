locals {
  zone_a = "us-east-1a"
}

resource "aws_vpc" "egress_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    "Name" = "egress-VPC"
  }
}

resource "aws_subnet" "snet_pvt_egress" {
  vpc_id            = aws_vpc.egress_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = local.zone_a
  tags = {
    "Name" = "snet-egress-pvt"
  }
}

resource "aws_subnet" "snet_pub_egress" {
  vpc_id            = aws_vpc.egress_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.zone_a
  map_public_ip_on_launch = true

  tags = {
    "Name" = "snet-egress-pub"
  }
}

resource "aws_subnet" "snet_pvt_fw" {
  vpc_id            = aws_vpc.egress_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.zone_a
  tags = {
    "Name" = "snet-egress-fw"
  }
}

resource "aws_internet_gateway" "ingw" {
  vpc_id = aws_vpc.egress_vpc.id

  tags = {
    "Name" = "internet-gateway"
  }
}

resource "aws_route_table" "rt_pub_snet_egress_vpc" {
  vpc_id = aws_vpc.egress_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ingw.id
  }
  route {
    cidr_block = "10.1.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    "Name" = "rt-pub-sb-vpc-egress"
  }
}

resource "aws_route_table_association" "snet_rt_pub_egress" {
  subnet_id      = aws_subnet.snet_pub_egress.id
  route_table_id = aws_route_table.rt_pub_snet_egress_vpc.id
}

resource "aws_route_table" "rt_pvt_snet_egress_vpc" {
  vpc_id = aws_vpc.egress_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ntgw.id
  }
  tags = {
    "Name" = "rt-pvt-sb-vpc-egress"
  }
}

resource "aws_route_table_association" "snet_rt_pvt_egress" {
  subnet_id      = aws_subnet.snet_pvt_egress.id
  route_table_id = aws_route_table.rt_pvt_snet_egress_vpc.id
}

resource "aws_eip" "eip_ntgw" {
  tags = {
    "Name" = "eip-ntgw"
  }
}

resource "aws_nat_gateway" "ntgw" {
  allocation_id = aws_eip.eip_ntgw.id
  subnet_id     = aws_subnet.snet_pub_egress.id

  tags = {
    "Name" = "natgw"
  }
  depends_on = [aws_internet_gateway.ingw]
}

#################### Transit Gateway #######################################
resource "aws_ec2_transit_gateway" "tgw" {
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"

  tags = {
    "Name" = "tgw-01"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_vpc_workload_attach" {
  subnet_ids         = [aws_subnet.snet_pvt_b_workload.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.workload_vpc.id
  tags = {
    "Name" = "tgw-vpc-workload-attach"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_vpc_egress_attach" {
  subnet_ids         = [aws_subnet.snet_pvt_egress.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.egress_vpc.id
  tags = {
    "Name" = "tgw-vpc-egress-attach"
  }
}

resource "aws_ec2_transit_gateway_route_table" "rt_tgw" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "tgw-rt"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rt_workload" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_workload_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rt_egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_egress_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route" "tgw_rt_vpc_egress" {
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_egress_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propag_egress" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_egress_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw_propag_workload" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_workload_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route" "tgw_rt_vpc_egress_nat" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_egress_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}

resource "aws_ec2_transit_gateway_route" "tgw_rt_vpc_workload" {
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_vpc_workload_attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_tgw.id
}


####################### ec2 ###############################
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-rvs"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "vm_bastion" {
  ami           = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.sg_bastion.id]

  subnet_id = aws_subnet.snet_pub_egress.id

  tags = {
    "Name" = "vm-bastion"
  }
}

resource "aws_security_group" "sg_bastion" {
  name_prefix = "allow-all-traffic"

  vpc_id = aws_vpc.egress_vpc.id 
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    "Name" = "SG-bastion"
  }
}