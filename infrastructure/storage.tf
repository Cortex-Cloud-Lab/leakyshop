resource "aws_s3_bucket" "public_assets" {
  bucket = "leaky-bucket-shop-public-data-12345"
  # MISCONFIG: Public Read/Write
  acl    = "public-read-write"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "no_enc" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.public_assets.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadWrite",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "${aws_s3_bucket.public_assets.arn}/*"
    }
  ]
}
EOF
}