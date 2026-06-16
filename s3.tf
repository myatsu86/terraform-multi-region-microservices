resource "aws_s3_bucket" "fake_service_binary" {
  bucket = "fake-service-203932541249"

  tags = {
    Name = "fake-service-binary"
  }
}

resource "aws_s3_bucket_public_access_block" "fake_service_binary" {
  bucket                  = aws_s3_bucket.fake_service_binary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_vpc_endpoint" "s3_private1" {
  region            = local.vpc_region["vpc-private-1"]
  vpc_id            = module.vpc["vpc-private-1"].vpc_id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc["vpc-private-1"].route_table_id]

  tags = {
    Name = "s3-endpoint-vpc-private-1"
  }
}

resource "aws_vpc_endpoint" "s3_private2" {
  region            = local.vpc_region["vpc-private-2"]
  vpc_id            = module.vpc["vpc-private-2"].vpc_id
  service_name      = "com.amazonaws.eu-west-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.vpc["vpc-private-2"].route_table_id]

  tags = {
    Name = "s3-endpoint-vpc-private-2"
  }
}




