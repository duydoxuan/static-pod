# provider.tf
provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}


# main.tf
resource "aws_key_pair" "example" {
  key_name   = "kubelet-key"
  public_key = var.public_key
}

resource "aws_security_group" "example_sg" {
  name   = "example_sg"
  vpc_id = var.vpc_id

  ingress {
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
}

resource "aws_instance" "example" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    host        = self.public_ip
  }
}

resource "null_resource" "file_upload" {
  depends_on = [aws_instance.example]

  triggers = {
    file_md5 = md5(file("/home/beancloud/worker_script/scripts/kubelet.sh"))
    instance_id = aws_instance.example.id
  }

  provisioner "file" {
    source      = "/home/beancloud/worker_script/scripts/kubelet.sh"
    destination = "/tmp/kubelet.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key)
      host        = aws_instance.example.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/kubelet.sh",
      "/tmp/kubelet.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key)
      host        = aws_instance.example.public_ip
    }
  }
}


