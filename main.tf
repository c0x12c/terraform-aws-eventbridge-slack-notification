resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "${var.name}-lambda-logging-policy"
  description = "IAM policy for Lambda function to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = each.value
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "notifier" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name}-notifier"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda_handler
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime

  environment {
    variables = merge(
      {
        SLACK_WEBHOOK_URL = var.slack_webhook_url
        ENVIRONMENT       = var.environment
      },
      var.lambda_environment_variables
    )
  }

  depends_on = [aws_iam_role.lambda_exec_role]
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = { for rule in var.event_rules : rule.name => rule }

  name          = "${var.name}-each.value.name"
  description   = each.value.description
  event_pattern = jsonencode(each.value.event_pattern)
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = { for rule in var.event_rules : rule.name => rule }

  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "${var.name}-SendToLambda-${each.key}"
  arn       = aws_lambda_function.notifier.arn

  depends_on = [aws_lambda_function.notifier]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = { for rule in var.event_rules : rule.name => rule }

  statement_id  = "${var.name}-AllowExecutionFromEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this[each.key].arn

  depends_on = [aws_lambda_function.notifier]
}
