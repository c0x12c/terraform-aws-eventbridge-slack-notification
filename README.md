# AWS EventBridge Slack Notification Module

This module creates a reusable notification system that sends AWS EventBridge events to Slack using Lambda.

## Features

- Lambda function for processing EventBridge events and sending to Slack
- IAM role and policies for Lambda execution
- Support for multiple EventBridge rules
- Customizable Lambda handler and runtime
- Support for additional IAM policies (service-specific permissions)

## Usage

```hcl
module "notification" {
  source = "../terraform-aws-eventbridge-slack-notification"

  name              = "my-service-notifier"
  environment       = "production"
  slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

  lambda_source_file = "${path.module}/files/index.mjs"
  lambda_handler     = "index.handler"
  lambda_runtime     = "nodejs20.x"

  lambda_environment_variables = {
    SERVICE_NAME = "my-service"
  }

  additional_iam_policy_arns = [
    aws_iam_policy.service_specific_policy.arn
  ]

  event_rules = [
    {
      name        = "my-service-events"
      description = "Service events"
      event_pattern = {
        source      = ["aws.ecs"]
        detail-type = ["ECS Task State Change"]
      }
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |
| archive | >= 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name prefix for all resources | `string` | n/a | yes |
| environment | The environment name | `string` | n/a | yes |
| slack_webhook_url | Slack webhook URL for sending notifications | `string` | n/a | yes |
| lambda_source_file | Path to the Lambda function source file | `string` | n/a | yes |
| lambda_handler | Lambda function handler | `string` | `"index.handler"` | no |
| lambda_runtime | Lambda function runtime | `string` | `"nodejs20.x"` | no |
| lambda_environment_variables | Additional environment variables for the Lambda function | `map(string)` | `{}` | no |
| additional_iam_policy_arns | Additional IAM policy ARNs to attach to the Lambda execution role | `list(string)` | `[]` | no |
| event_rules | List of EventBridge rule configurations | `list(object)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | ARN of the Lambda function |
| lambda_function_name | Name of the Lambda function |
| iam_role_arn | ARN of the Lambda execution IAM role |
| iam_role_name | Name of the Lambda execution IAM role |
| event_rule_arns | ARNs of the CloudWatch Event Rules |
