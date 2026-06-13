# Deploys the fake-service binary onto the private instances.


resource "null_resource" "setup_account" {
  depends_on = [
    aws_route.public_to_private1,
    aws_route.private1_to_public,
  ]

  triggers = {
    instance_id = module.ec2_account.instance_id
    bastion_id  = module.ec2_customer_profile.instance_id
    script_hash = filesha256("${path.module}/scripts/deploy-binary.sh")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.this.private_key_openssh
    host        = module.ec2_customer_profile.public_ip
    host_key            = null  # disables strict host checking
    timeout             = "5m"
  }

  provisioner "file" {
    content     = tls_private_key.this.private_key_openssh
    destination = "/home/ubuntu/.ssh/tf_key"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/deploy-binary.sh"
    destination = "/home/ubuntu/deploy-binary.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/tf_key",
      "chmod +x /home/ubuntu/deploy-binary.sh",
      "/home/ubuntu/deploy-binary.sh ${module.ec2_account.private_ip} account.service",
    ]
  }
}

resource "null_resource" "setup_statement" {
  depends_on = [
    aws_route.public_to_private2,
    aws_route.private2_to_public,
  ]

  triggers = {
    instance_id = module.ec2_statement.instance_id
    bastion_id  = module.ec2_customer_profile.instance_id
    script_hash = filesha256("${path.module}/scripts/deploy-binary.sh")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.this.private_key_openssh
    host        = module.ec2_customer_profile.public_ip
    host_key            = null  # disables strict host checking
    timeout             = "5m"
  }

  provisioner "file" {
    content     = tls_private_key.this.private_key_openssh
    destination = "/home/ubuntu/.ssh/tf_key"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/deploy-binary.sh"
    destination = "/home/ubuntu/deploy-binary.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/tf_key",
      "chmod +x /home/ubuntu/deploy-binary.sh",
      "/home/ubuntu/deploy-binary.sh ${module.ec2_statement.private_ip} statement.service",
    ]
  }
}
