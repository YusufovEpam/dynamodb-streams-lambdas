variable "npm_token" {}
variable "role_arn" {}
variable "stream_arn" {}
variable "node_env" {}
variable "org" {}

resource "null_resource" "transaction_documents_validator_function_null" {
  triggers = {
    index = random_uuid.transaction_documents_validator_src_hash.result
  }
  provisioner "local-exec" {
    command = "npm config set '//registry.npmjs.org/:_authToken' ${var.npm_token}; npm ci; npm run build; rm -r node_modules; npm ci --production"
    working_dir = "./lambda/transaction-documents-validator/fn"
  }
}

data "archive_file" "transaction_documents_validator_function_zip" {
  type = "zip"
  source_dir = "./lambda/transaction-documents-validator/fn"
  output_path = "./lambda/transaction-documents-validator/output/${random_uuid.transaction_documents_validator_src_hash.result}.zip"
  depends_on = [
    null_resource.transaction_documents_validator_function_null]
}

resource "random_uuid" "transaction_documents_validator_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("lambda/transaction-documents-validator/fn", "/*")
    ):
    filename => filemd5("lambda/transaction-documents-validator/fn/${filename}")
  }
}

resource "aws_lambda_function" "transaction_documents_validator" {
  function_name = "${terraform.workspace}-fn-transaction-documents-validator"
  description = "${terraform.workspace} Validator for DynamoDB Stream on ${terraform.workspace}.TransactionDocuments table."
  handler = "index.lambdaHandler"
  runtime = "nodejs12.x"
  filename = "./lambda/transaction-documents-validator/output/${random_uuid.transaction_documents_validator_src_hash.result}.zip"
  role = var.role_arn
  memory_size = 128
  timeout = 30

  environment {
    variables = {
      NODE_ENV = terraform.workspace
    }
  }

  tags = {
    Name = "validator:transaction-documents"
    Organization = var.org
  }

  depends_on = [
    data.archive_file.transaction_documents_validator_function_zip]
}

resource "aws_lambda_event_source_mapping" "transaction_documents_validator_source" {
  batch_size = 100
  event_source_arn = var.stream_arn
  enabled = true
  function_name = aws_lambda_function.transaction_documents_validator.function_name
  starting_position = "TRIM_HORIZON"
}

###############
### OUTPUTS ###
###############

output "transaction_documents_validator_arn" {
  value = aws_lambda_function.transaction_documents_validator.arn
}

output "transaction_documents_validator_invoke_arn" {
  value = aws_lambda_function.transaction_documents_validator.invoke_arn
}

output "transaction_documents_validator_qualified_arn" {
  value = aws_lambda_function.transaction_documents_validator.qualified_arn
}
