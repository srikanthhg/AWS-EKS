resource "aws_instance" "bootstrap" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = data.aws_subnets.public_subnets[0].id #aws_subnet.public[0].id
  associate_public_ip_address = true
  instance_type               = "t3.medium"
  key_name                    = "hipstershop"
  iam_instance_profile        = "myrole08022024"
  vpc_security_group_ids      = [aws_security_group.allow_tls.id]
  user_data                   = file("bootstrap.sh")

  # root_block_device {
  #   volume_type = "gp2"
  #   volume_size = "30"
  # }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "gp2"
  }

  tags = {
    Name = "Bootstrap"
  }

  # depends_on = [aws_eks_node_group.ondemand-node]
}