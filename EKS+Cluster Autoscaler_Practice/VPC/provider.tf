terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket            = "expensee-dev"
    key               = "vpc/expense-dev.tfstate"
    region            = "us-east-1"
    dynamodb_endpoint = "expensee-locking"
    # encrypt = true
  }

}

# Configure the AWS Provider
provider "aws" {
  #   region = "us-east-1"
}
