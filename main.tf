terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0-beta2"
}
}
}

provider "aws" {
  region = "eu-central-1"
}

# 1. VPC
resource "aws_vpc" "create_vpc"   {       #hey i create vpc ,tf:ok and give tag name:,tf-ok           
  cidr_block = "11.0.0.0/16"
  tags = {
    Name = "tf_vpc" #naming it 
  }
}

# 2. Private Subnet
resource "aws_subnet" "create_pri_sub" {
  vpc_id            = aws_vpc.create_vpc.id
  cidr_block        = "11.0.1.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "tf_pri_sub"  #naming it 
  }
}

# 3. Public Subnet
resource "aws_subnet" "create_pub_sub" {
  vpc_id            = aws_vpc.create_vpc.id
  cidr_block        = "11.0.2.0/24"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "tf_pub_sub"
  }
}

# 4. Internet Gateway
resource "aws_internet_gateway" "create_igw" {
  vpc_id = aws_vpc.create_vpc.id

  tags = {
    Name = "igw-for-pub-sub"
  }
}

# 5. Public Route Table
resource "aws_route_table" "create_pub_rt" {
  vpc_id = aws_vpc.create_vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.create_igw.id   #asks for gateway id ticket 
  }

  tags = {
    Name = "tf-pub-rt"
  }
}

# 6. Associate pub Route Table with Public Subnet
resource "aws_route_table_association" "associating_pub_RT_with_pub_sub" {
  subnet_id      = aws_subnet.create_pub_sub.id
  route_table_id = aws_route_table.create_pub_rt.id  #paste that pub rt ticket beside.id
}

# 7. Private Route Table
resource "aws_route_table" "create_pri_rt" {
  vpc_id = aws_vpc.create_vpc.id

  tags = {
    Name = "tf-pri-rt"
  }
}

# 8. Associate pri Route Table with Private Subnet
resource "aws_route_table_association" "associating_pri_RT_with_pri_sub" {
  subnet_id      = aws_subnet.create_pri_sub.id
  route_table_id = aws_route_table.create_pri_rt.id
}


###key gen

resource "tls_private_key" "tf_shall_gen_keys" {    
  algorithm = "RSA"
  rsa_bits  = 4096
  
}
resource "aws_key_pair" "uploading_pub_key_to_aws" {
  key_name   = "tf-key" #with key name 
  public_key = tls_private_key.tf_shall_gen_keys.public_key_openssh  ##tls has gen keys                   with ref to tf_shall_gen_keys 
}

resource "local_file" "uploading_pri_key_to_linux" {
  content  = tls_private_key.tf_shall_gen_keys.private_key_pem
  filename = "/home/dom/keys/tf-key.pem"   # Save the private key to a file
  file_permission = "0600"  # Set permissions to read/write for the owner only 
}


resource "aws_security_group" "create_SG_for_ec2" {  #ticket
  name        = "SG-for-ec2"
  description = "Security group for public subnet"
  vpc_id      = aws_vpc.create_vpc.id  


    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere
    }


egress {      
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
}


}


 resource "aws_instance" "create_a_instance" {
  ami           = "ami-02b7d5b1e55a7b5f1"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.create_pub_sub.id
  key_name      = aws_key_pair.uploading_pub_key_to_aws.key_name  #********* tf whats the key name its tf-key above iam giving key_name tf:ok
  vpc_security_group_ids = [aws_security_group.create_SG_for_ec2.id]
  associate_public_ip_address = true  # This will assign a public IP to the instance

  

  tags = {
    Name = "Dr_pal_instance"  # Name of the instance
  }
}
output "instance_public_ip" {
  value = aws_instance.create_a_instance.public_ip
}