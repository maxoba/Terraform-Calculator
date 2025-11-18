resource "aws_instance" "calculator" {
  ami           = data.aws_ami.example.id
  instance_type = var.my_instance         # Correct reference to the variable

  key_name  = var.my_key
  user_data = file("cal.sh")
   vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  tags = {
    Name = "calculator"
  }
}



resource "time_sleep" "wait_for_instance" {
  create_duration = "240s"

  depends_on = [aws_instance.calculator]
}


resource "aws_security_group" "allow_ssh_http" {
  name_prefix = "allow_ssh_http-"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "allow_ssh_http"
  }
}


