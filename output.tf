output "public_ip" {
  value = aws_instance.calculator.public_ip
}

output "private_ip" {
  value = aws_instance.calculator.private_ip
}

