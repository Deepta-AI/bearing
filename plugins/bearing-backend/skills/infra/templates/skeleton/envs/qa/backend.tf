terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # __BACKEND__: remote, locked state. Exactly one backend block is active;
  # the `cloud` key of the tech-decision record for this repository says which.
  # The bucket name arrives at init time (make init ENV=qa and CI pass
  # -backend-config="bucket=$TF_BACKEND_BUCKET") so this file is identical in
  # every checkout and runner; the prefix is fixed per environment.

  # GCP: Google Cloud Storage (active).
  backend "gcs" {
    prefix = "envs/qa"
  }

  # AWS: S3. Uncomment this block, remove the gcs block, and switch the
  # provider in main.tf. S3 locks natively from Terraform 1.10 (use_lockfile);
  # on 1.9 a DynamoDB table holds the lock.
  # backend "s3" {
  #   key            = "envs/qa/terraform.tfstate"
  #   region         = "ap-south-1"
  #   encrypt        = true
  #   dynamodb_table = "__REPO_SLUG__-tflock"
  # }

  # GitLab-managed state (fastest start, no bucket to create):
  # backend "http" {}
  # then init with the address, lock_address and unlock_address flags
  # from the GitLab docs, or use the registry.gitlab.com/gitlab-org/
  # terraform-images wrapper.
}
