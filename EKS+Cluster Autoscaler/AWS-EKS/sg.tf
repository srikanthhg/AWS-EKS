resource "aws_security_group" "cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Node groups to cluster API"
  vpc_id      = data.aws_vpc.main.id

  #argocd no need
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    description = "Node groups to cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # should be specific IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" #all protocols are allowed
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cluster-sg"
  }
}