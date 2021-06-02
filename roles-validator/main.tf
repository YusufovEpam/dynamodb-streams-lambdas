variable "npm_token" {}
variable "role_arn" {}
variable "stream_arn" {}
variable "org" {}

resource "null_resource" "roles_validator_function_null" {
  triggers = {
    index = random_uuid.roles_validator_src_hash.result
  }
  provisioner "local-exec" {
    command = "npm config set '//registry.npmjs.org/:_authToken' ${var.npm_token}; npm ci; npm run build; npm ci --production"
    working_dir = "./lambda/roles-validator/fn"
  }
}

data "archive_file" "roles_validator_function_zip" {
  type = "zip"
  source_dir = "./lambda/roles-validator/fn"
  output_path = "./lambda/roles-validator/output/${random_uuid.roles_validator_src_hash.result}.zip"
  depends_on = [
    null_resource.roles_validator_function_null]
}

resource "random_uuid" "roles_validator_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("lambda/roles-validator/fn", "/*"),
    ):
    filename => filemd5("lambda/roles-validator/fn/${filename}")
  }
}

resource "aws_lambda_function" "roles_validator" {
  function_name = "${terraform.workspace}-fn-roles-validator"
  description = "${terraform.workspace} Validator for roles Stream on ${terraform.workspace}.Roles table."
  handler = "index.lambdaHandler"
  runtime = "nodejs10.x"
  filename = "./lambda/roles-validator/output/${random_uuid.roles_validator_src_hash.result}.zip"
  role = var.role_arn

  memory_size = 128
  timeout = 30
  environment {
    variables = {
      NODE_ENV = terraform.workspace
    }
  }

  tags = {
    Name = "validator:roles"
    Organization = var.org
  }

  depends_on = [
    data.archive_file.roles_validator_function_zip]
}

resource "aws_lambda_event_source_mapping" "roles_validator_source" {
  batch_size = 100
  event_source_arn = var.stream_arn
  enabled = true
  maximum_record_age_in_seconds = 604800
  function_name = aws_lambda_function.roles_validator.function_name
  starting_position = "TRIM_HORIZON"
}

###############
### OUTPUTS ###
###############

output "roles_validator_arn" {
  value = aws_lambda_function.roles_validator.arn
}

output "roles_validator_invoke_arn" {
  value = aws_lambda_function.roles_validator.invoke_arn
}

output "roles_validator_qualified_arn" {
  value = aws_lambda_function.roles_validator.qualified_arn
}
