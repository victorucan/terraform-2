terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
provider "aws" {
  shared_config_files      = ["/home/ubuntu/.aws/conf"]
  shared_credentials_files = ["/home/ubuntu/.aws/creds"]
  profile                  = "default"
}