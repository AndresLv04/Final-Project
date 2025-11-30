# IAM policy to allow portal task to invoke PDF Lambda
resource "aws_iam_role_policy" "portal_invoke_pdf_lambda" {
  name = "${var.project_name}-${var.environment}-portal-invoke-pdf-lambda"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.pdf_lambda_function_arn
      }
    ]
  })
}

