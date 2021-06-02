variable "role_arn" {}
variable "stream_arn" {}
variable "segment_server_key" {}
variable "npm_token" {
  type = string
}
variable "org" {}

resource "null_resource" "users_validator_function_null" {
  triggers = {
    index = random_uuid.users_validator_src_hash.result
  }

  provisioner "local-exec" {
    command = "npm config set '//registry.npmjs.org/:_authToken' ${var.npm_token}; npm ci; npm run build; npm ci --production"
    working_dir = "./lambda/users-validator/fn"
  }
}

data "archive_file" "users_validator_function_zip" {
  type = "zip"
  source_dir = "./lambda/users-validator/fn"
  output_path = "./lambda/users-validator/output/${random_uuid.users_validator_src_hash.result}.zip"
  depends_on = [
    null_resource.users_validator_function_null]
}

resource "random_uuid" "users_validator_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("lambda/users-validator/fn", "/*")
    ):
    filename => filemd5("lambda/users-validator/fn/${filename}")
  }
}

resource "aws_lambda_function" "users_validator" {
  function_name = "${terraform.workspace}-fn-users-validator"
  description = "${terraform.workspace} Validator for DynamoDB Stream on ${terraform.workspace}.Users table."
  handler = "index.lambdaHandler"
  runtime = "nodejs10.x"
  filename = "./lambda/users-validator/output/${random_uuid.users_validator_src_hash.result}.zip"
  role = var.role_arn
  memory_size = 128
  timeout = 30

  environment {
    variables = {
      NODE_ENV = terraform.workspace
      SEGMENT_SERVER_KEY = var.segment_server_key
    }
  }

  tags = {
    Name = "validator:users"
    Organization = var.org
  }

  depends_on = [
    data.archive_file.users_validator_function_zip]
}

resource "aws_lambda_event_source_mapping" "users_validator_source" {
  batch_size = 100
  event_source_arn = var.stream_arn
  enabled = true
  maximum_record_age_in_seconds = 604800
  function_name = aws_lambda_function.users_validator.function_name
  starting_position = "TRIM_HORIZON"
}

###############
### OUTPUTS ###
###############

output "users_validator_arn" {
  value = aws_lambda_function.users_validator.arn
}

output "users_validator_invoke_arn" {
  value = aws_lambda_function.users_validator.invoke_arn
}

output "users_validator_qualified_arn" {
  value = aws_lambda_function.users_validator.qualified_arn
}
