module "labels" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.24.1"
  context     = var.context
  name        = var.name
  label_order = var.label_order
}

module "notify_slack_module" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "~> 4.0"

  sns_topic_name       = "terraform_notify_sns_slack"
  lambda_function_name = "notify_slack_module"

  slack_webhook_url = var.slack_webhook_url
  slack_channel     = "aws-notification"
  slack_username    = var.author_name
}

resource "aws_sns_topic" "this" {
  name = "${module.labels.id}_error_sns_topic_slack"
}

data "aws_region" "current" {}

resource "null_resource" "self" {
  for_each = var.alarm_emails
  provisioner "local-exec" {
    command = <<EOF
        aws \
            --region ${data.aws_region.current.name} \
            sns subscribe \
                --topic-arn ${aws_sns_topic.this.arn} \
                --protocol email \
                --notification-endpoint ${each.value}
    EOF
  }
}

resource "aws_iam_role" "iam_for_error_generating" {
  name = "${module.labels.id}_for_error_generating"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
  EOF
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "error_generating_policy" {
  name = module.labels.id
  role = aws_iam_role.iam_for_error_generating.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": aws_sns_topic.this.arn
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:*:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*"
        }
    ]
  })
}

data "archive_file" "error_generating" {
  type        = "zip"
  source_file = "${path.module}/lamda-functions/error-generating-Lambda/error-generating-Lambda.py"
  output_path = "modules/notified_Lambda/eu-central-1/lamda-functions/error-generating-Lambda/error-generating-Lambda.zip"
}

resource "aws_lambda_function" "error_generating_Lambda" {
  filename      = data.archive_file.error_generating.output_path
  function_name = "${module.labels.id}-error-generating-Lambda"
  role          = aws_iam_role.iam_for_error_generating.arn
  handler       = "error-generating-Lambda.lambda_handler"

#   # The filebase64sha256() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
#   # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.error_generating.output_base64sha256

   runtime = "python3.7"
}

data "archive_file" "lambda_function_notified" {
  type        = "zip"
  source_file = "${path.module}/lamda-functions/lambda-function-notified/lambda-function-notified.py"
  output_path = "modules/notified_Lambda/eu-central-1/lamda-functions/lambda-function-notified/lambda-function-notified.zip"
}

resource "aws_lambda_function" "lambda_function_notified" {
  filename      = data.archive_file.lambda_function_notified.output_path
  function_name = "${module.labels.id}-lambda-function-notified"
  role          = aws_iam_role.iam_for_error_generating.arn
  handler       = "error-generating-Lambda.lambda_handler"

#   # The filebase64sha256() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
#   # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.lambda_function_notified.output_base64sha256

   runtime = "python3.7"
   environment {
     variables = {
       snsARN=aws_sns_topic.this.arn
     }
   }
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  name           = "1${module.labels.id}"
  pattern        = "?ERROR ?WARN ?5xx"
  log_group_name = "/aws/lambda/${aws_lambda_function.error_generating_Lambda.function_name}"

  metric_transformation {
    name      = module.labels.id
    namespace = module.labels.id
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name                = module.labels.id
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = module.labels.id
  namespace                 = module.labels.id
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "This metric monitors ${module.labels.id}"
  treat_missing_data        = "notBreaching"
  alarm_actions             = [aws_sns_topic.this.arn, module.notify_slack_module.this_slack_topic_arn]
}