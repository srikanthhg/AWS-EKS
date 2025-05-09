output "ec2_public_ip" {
  value = aws_instance.bootstrap.public_ip
}