##################################################################################
resource "aws_s3_bucket" "state_bucket" {
  # bucket        = local.bucket_name
  bucket        = "lineten-kubernetes"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

}
##################################################################################
