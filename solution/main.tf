terraform {
  required_version = ">= 1.3"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.3.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "4.58.0"
    }
  }
}

provider "archive" {
}

provider "aws" {
  region = "us-east-1"
}

locals {
  s3_origin_id_1  = "myS3Origin-1"
  s3_origin_id_2  = "myS3Origin-2"
  lambda_zip_path = "function.zip"
}

### Resources ###

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "s3-cloudfront-oac"
  description                       = "Grant cloudfront access to s3 buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "policy_bucket_1" {
  name = "demo_policy_bucket_1"

  min_ttl     = 172800 # 48 Hours
  default_ttl = 172800 # 48 Hours
  max_ttl     = 604800 # 1 week

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_cache_policy" "policy_bucket_2" {
  name = "demo_policy_bucket_2"

  min_ttl = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["CloudFront-Viewer-Country", "x-host"]
      }
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bucket_1.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = local.s3_origin_id_1
  }

  origin {
    domain_name              = aws_s3_bucket.bucket_2.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = local.s3_origin_id_2
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id_1

    cache_policy_id = aws_cloudfront_cache_policy.policy_bucket_1.id

    viewer_protocol_policy = "allow-all"
  }

  ordered_cache_behavior {
    path_pattern     = "/devops-folder/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id_2

    cache_policy_id = aws_cloudfront_cache_policy.policy_bucket_2.id

    viewer_protocol_policy = "allow-all"

    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = aws_lambda_function.test_lambda.qualified_arn
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.custom_host.arn
    }
  }

  price_class = "PriceClass_All"

  tags = {
    Environment = "cf-demo"
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket" "bucket_1" {
  bucket_prefix = "cf-demo-1-"

  tags = {
    Name = "CF Demo 1"
  }
}

resource "aws_s3_bucket_acl" "bucket_1_acl" {
  bucket = aws_s3_bucket.bucket_1.id
  acl    = "private"
}

data "aws_iam_policy_document" "read_bucket_1" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.bucket_1.arn,
      "${aws_s3_bucket.bucket_1.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "read_bucket_1" {
  bucket = aws_s3_bucket.bucket_1.id
  policy = data.aws_iam_policy_document.read_bucket_1.json
}

resource "aws_s3_object" "bucket_1_index_html" {
  bucket = aws_s3_bucket.bucket_1.id
  key    = "index.html"
  source = "static/bucket_1/index.html"

  etag         = filemd5("static/bucket_1/index.html")
  content_type = "text/html; charset=utf-8"
}

resource "aws_s3_bucket" "bucket_2" {
  bucket_prefix = "cf-demo-2-"

  tags = {
    Name = "CF Demo 1"
  }
}

resource "aws_s3_bucket_acl" "bucket_2_acl" {
  bucket = aws_s3_bucket.bucket_2.id
  acl    = "private"
}

data "aws_iam_policy_document" "read_bucket_2" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.bucket_2.arn,
      "${aws_s3_bucket.bucket_2.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "read_bucket_2" {
  bucket = aws_s3_bucket.bucket_2.id
  policy = data.aws_iam_policy_document.read_bucket_2.json
}

resource "aws_s3_object" "bucket_2_index_html" {
  bucket = aws_s3_bucket.bucket_2.id
  key    = "index.html"
  source = "static/bucket_2/index.html"

  etag         = filemd5("static/bucket_2/index.html")
  content_type = "text/html; charset=utf-8"
}

resource "aws_iam_role" "lambda_edge_exec" {
  assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        },
        "Effect": "Allow"
        }
    ]
    }
    EOF
}

data "archive_file" "zip_file_for_lambda" {
  type        = "zip"
  source_file = "src/index.js"
  output_path = local.lambda_zip_path
}

resource "aws_lambda_function" "test_lambda" {
  filename      = local.lambda_zip_path
  function_name = "cf-demo-default-directory-index"
  role          = aws_iam_role.lambda_edge_exec.arn

  source_code_hash = data.archive_file.zip_file_for_lambda.output_base64sha256

  runtime = "nodejs16.x"
  handler = "index.handler"

  publish = true
}

resource "aws_cloudfront_function" "custom_host" {
  name    = "custom_host"
  runtime = "cloudfront-js-1.0"
  comment = "copy Host header into a custom header"
  publish = true
  code    = file("src/function.js")
}

### Outputs ###
output "distribution_url" {
  value = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}/"
}
