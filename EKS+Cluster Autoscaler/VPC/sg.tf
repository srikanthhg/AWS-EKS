# for ec2 instance
resource "aws_security_group" "allow_tls" {
  name        = "allow_all"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  
    ingress {
    description = "Allow_All"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow_All"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow_All"
    from_port   = 1194
    to_port     = 1194
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
    Name = "allow_all"
  }
}

# resource "aws_security_group" "cluster_sg" {
#   name        = "eks-cluster-sg"
#   description = "Node groups to cluster API"
#   vpc_id      = aws_vpc.main.id

#   #argocd no need
#   # ingress {
#   #   from_port   = 80
#   #   to_port     = 80
#   #   protocol    = "tcp"
#   #   cidr_blocks = ["0.0.0.0/0"]
#   # }

#   ingress {
#     description = "Node groups to cluster API"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # should be specific IP
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1" #all protocols are allowed
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "cluster-sg"
#   }
# }