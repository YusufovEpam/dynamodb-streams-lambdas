variable "role_arn" {}
variable "stream_arn" {}
variable "npm_token" {}
variable "segement_server_key" {
  type = map(string)
  description = "Segment.com API Key (Node.js Source)"
  default = {
    production  = "F7KCP0Y2ahUbcbXwFDq5zfChktTsCMZA"
    staging     = "wb6OaBGzuGSEwoPn64ggkNtKCCHDZowl"
    staging2    = "wb6OaBGzuGSEwoPn64ggkNtKCCHDZowl"
    test        = "UIh8FIm9ivdoe9DAOf7D5QxnDmS2cqDA"
    test-eks    = "UIh8FIm9ivdoe9DAOf7D5QxnDmS2cqDA"
    development = "vtxeudWNwo8LF2MhgK4xFwmd68S0cWR3"
    integration = "vtxeudWNwo8LF2MhgK4xFwmd68S0cWR3"
  }
}
variable "notification_secret_value" {
  type = string
  default = "dc47adad-0c47-47f7-a516-975206053024"
}

variable "notification_service_domain" {
  type = map(string)

  description = "Notification API url. Format: fully.qualified.domain Map: workspace/domain"

  # default = {
  #   production  = "notifications.internal.endpointclosing.com"
  #   staging     = "notifications-staging.internal.endpointclosing.com"
  #   test        = "notifications-test.internal.endpointclosing.com"
  #   test-eks    = "notifications-test-eks.internal.endpointclosing.com"
  #   development = "notifications-dev.internal.endpointclosing.com"
  # }

  default = {
    # TODO: Remove hardcoded URL once we have a better deployment
    production  = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    # Hardcoded
    staging     = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    staging2    = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    test        = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    test-eks    = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    development = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
    integration = "http://ec2-54-71-33-79.us-west-2.compute.amazonaws.com:8080/"
  }
}

variable org {}

resource "null_resource" "transactions_validator_function_null" {
  triggers = {
    index = random_uuid.transactions_validator_src_hash.result
  }
  provisioner "local-exec" {
    command = "npm config set '//registry.npmjs.org/:_authToken' ${var.npm_token}; npm ci; npm run build; npm ci --production"
    working_dir = "./lambda/transactions-validator/fn"
  }
}

data "archive_file" "transactions_validator_function_zip" {
  type = "zip"
  source_dir = "./lambda/transactions-validator/fn"
  output_path = "./lambda/transactions-validator/output/${random_uuid.transactions_validator_src_hash.result}.zip"
  depends_on = [
    null_resource.transactions_validator_function_null]
}

resource "random_uuid" "transactions_validator_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("lambda/transactions-validator/fn", "/*")
    ):
    filename => filemd5("lambda/transactions-validator/fn/${filename}")
  }
}

resource "aws_lambda_function" "transactions_validator" {
  function_name = "${terraform.workspace}-fn-transactions-validator"
  description = "${terraform.workspace} Validator for DynamoDB Stream on ${terraform.workspace}.Tasks table."
  handler = "index.lambdaHandler"
  runtime = "nodejs10.x"
  filename = "./lambda/transactions-validator/output/${random_uuid.transactions_validator_src_hash.result}.zip"
  role = var.role_arn
  memory_size = 128
  timeout = 30

  environment {
    variables = {
      NODE_ENV = terraform.workspace
      SEGMENT_SERVER_KEY = var.segement_server_key[terraform.workspace]
      NOTIFICATION_SERVICE_DOMAIN = var.notification_service_domain[terraform.workspace]
      NOTIFICATION_SECRET_VALUE = var.notification_secret_value
    }
  }

  tags = {
    Name = "validator:transactions"
    Organization = var.org
  }

  depends_on = [
    data.archive_file.transactions_validator_function_zip]
}

resource "aws_lambda_event_source_mapping" "transactions_validator_source" {
  batch_size = 100
  event_source_arn = var.stream_arn
  enabled = true
  maximum_record_age_in_seconds = 604800
  function_name = aws_lambda_function.transactions_validator.function_name
  starting_position = "TRIM_HORIZON"
}

###############
### OUTPUTS ###
###############

output "transactions_validator_arn" {
  value = aws_lambda_function.transactions_validator.arn
}

output "transactions_validator_invoke_arn" {
  value = aws_lambda_function.transactions_validator.invoke_arn
}

output "transactions_validator_qualified_arn" {
  value = aws_lambda_function.transactions_validator.qualified_arn
}
