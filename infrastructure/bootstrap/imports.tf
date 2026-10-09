# Temporary declarative import used to reconcile the existing Terraform
# backend bucket with its missing state address.
#
# The physical bucket already exists in AWS. This import prevents Terraform
# from attempting to create a replacement bucket and consequently replacing
# its separately managed hardening resources.
import {
  to = aws_s3_bucket.terraform_state
  id = "pcrp-terraform-state-us-east-1"
}
