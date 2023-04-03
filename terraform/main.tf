terraform {
  # Terraform state configuration
  backend "s3" {
    bucket     = "voidmaster-infrastructure-state"
    key        = "stage/eu-west-1/infrastructure-state"
    profile    = "cloud_guru"
    region     = "us-east-1"
  }
  # Terraform providers 'imports'
  required_providers {
    aws = { source = "hashicorp/aws", version = "3.62.0" }
  }
}

# AWS provider configuration
provider "aws" {
  region = var.region
}

# Declares a data structure of type aws_caller_identity called current
data "aws_caller_identity" "current" {

}

locals {
  root_dir   = "${path.module}/.."
  account_id    = data.aws_caller_identity.current.account_id
  memory_size   = 128
  timeout       = 10
  function_name = "${var.service_name}-lambda"
}

# ================ Lambda Definition ================

resource "aws_lambda_function" "lambda-function" {
  function_name = local.function_name
  image_uri     = "${aws_ecr_repository.lambda-image-repository.repository_url}@${data.aws_ecr_image.lambda-image.id}"
  package_type  = "Image"
  timeout       = local.timeout
  memory_size   = local.memory_size
  role          = aws_iam_role.lambda-role.arn
}

resource "aws_iam_role" "lambda-role" {
  name               = "${local.function_name}-${var.region}"
  assume_role_policy = data.aws_iam_policy_document.assume-role-policy.json
}

data "aws_iam_policy_document" "assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "basic-lambda-policy" {
  role       = aws_iam_role.lambda-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda-log-group" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_in_days
}

# ================ Image & Repository Definitions ================

resource "null_resource" "lambda-image-builder" {
  triggers = {
    docker_file     = filesha256("${local.root_dir}/Dockerfile")
    cargo_file      = filesha256("${local.root_dir}/Cargo.toml")
    cargo_lock_file = filesha256("${local.root_dir}/Cargo.lock")
    src_dir         = sha256(join("", [for f in fileset("${local.root_dir}/src", "**") : filesha256("${local.root_dir}/src/${f}")]))
  }

  provisioner "local-exec" {
    working_dir = local.root_dir
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.region}.amazonaws.com
      docker image build -t ${aws_ecr_repository.lambda-image-repository.repository_url}:${var.image_version} .
      docker push ${aws_ecr_repository.lambda-image-repository.repository_url}:${var.image_version}
    EOT
  }
}

resource "aws_ecr_repository" "lambda-image-repository" {
  name = local.function_name
}

data "aws_ecr_image" "lambda-image" {
  depends_on = [ null_resource.lambda-image-builder ]
  repository_name = local.function_name
  image_tag       = var.image_version
}
