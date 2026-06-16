resource "aws_iam_role" "ec2_s3_role" {
  name = "fake-service-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "fake-service-s3-read"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.fake_service_binary.arn}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "fake-service-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}
