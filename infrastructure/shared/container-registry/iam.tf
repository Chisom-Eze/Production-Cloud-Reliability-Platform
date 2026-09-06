data "aws_iam_policy_document" "github_development_ecr_publish" {
  statement {
    sid       = "AllowEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowPublishToProjectRepositories"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      for repository in module.ecr : repository.repository_arn
    ]
  }
}

resource "aws_iam_policy" "github_development_ecr_publish" {
  name        = "ProductionCloudReliabilityPlatformEcrPublish"
  description = "Least-privilege ECR image publishing policy for the GitHub development deployment role."
  policy      = data.aws_iam_policy_document.github_development_ecr_publish.json
}

resource "aws_iam_role_policy_attachment" "github_development_ecr_publish" {
  role       = var.github_development_deployment_role_name
  policy_arn = aws_iam_policy.github_development_ecr_publish.arn
}
