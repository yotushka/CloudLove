module "frontend" {
  source      = "./modules/s3/eu-central-1"
  context     = module.base_labels.context
  name        = "frontend"
  label_order = var.label_order
}

module "dynamo_db_courses" {
  source      = "./modules/dynamodb/eu-central-1"
  context     = module.base_labels.context
  name        = "courses"
}

module "dynamo_db_authors" {
  source      = "./modules/dynamodb/eu-central-1"
  context     = module.base_labels.context
  name        = "authors"
}

module "lambda" {
  source          = "./modules/lambda/eu-central-1"
  context         = module.base_labels.context
  name            = "lambda"
  role_get_all_authors_arn = module.iam.role_get_all_authors_arn
  role_get_all_courses_arn = module.iam.role_get_all_courses_arn
  role_get_course_arn = module.iam.role_get_course_arn
  role_save_update_course_arn = module.iam.role_save_update_course_arn
  role_delete_course_arn = module.iam.role_delete_course_arn

  dynamo_db_authors_name = module.dynamo_db_authors.dynamp_db_name
  dynamo_db_courses_name = module.dynamo_db_courses.dynamp_db_name

  api_gateway_execution_arn = aws_api_gateway_rest_api.this.execution_arn
}

module "iam" {
  source                = "./modules/iam"
  context               = module.base_labels.context
  name                  = "iam"
  dynamo_db_authors_arn = module.dynamo_db_authors.dynamp_db_arn
  dynamo_db_courses_arn = module.dynamo_db_courses.dynamp_db_arn
}

module "notified_Lambda" {
  source            = "./modules/notified_Lambda/eu-central-1"
  context           = module.base_labels.context
  name              = "notified_Lambda"
  alarm_emails      = var.alarm_emails
  slack_webhook_url = var.slack_webhook_url
  author_name       = var.author_name
}

module "budget" {
  source                     = "./modules/budget"
  context                    = module.base_labels.context
  name                       = "budget"
  subscriber_email_addresses = var.subscriber_email_addresses
  slack_webhook_url          = var.slack_webhook_url
  author_name                = var.author_name
}


resource "aws_dynamodb_table_item" "author" {
  table_name = module.dynamo_db_authors.dynamp_db_name
  hash_key   = module.dynamo_db_authors.dynamp_db_hash_key

  item = <<ITEM
  {
    "id": {"S": "cory-house"},
    "firstName": {"S": "Cory"},
    "lastName": {"S": "House"}
  }
ITEM
}

resource "aws_dynamodb_table_item" "course" {
  table_name = module.dynamo_db_courses.dynamp_db_name
  hash_key   = module.dynamo_db_courses.dynamp_db_hash_key

  item = <<ITEM
{
  "id": {"S": "web-components-shadow-dom"},
  "title": {"S": "Web Component Fundamentals"},
  "watchHref": {"S": "http://www.pluralsight.com/courses/web-components-shadow-dom"},
  "authorId": {"S": "cory-house"},
  "length": {"S": "5:10"},
  "category": {"S": "HTML5"}
}
ITEM
}