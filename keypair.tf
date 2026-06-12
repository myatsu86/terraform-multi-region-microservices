resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Key pairs are region-scoped: register the same public key in every region in use.
resource "aws_key_pair" "this" {
  for_each = local.regions

  region     = each.value
  key_name   = "my-key"
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.this.private_key_openssh
  filename        = "${path.module}/my-key.pem"
  file_permission = "0600"
}