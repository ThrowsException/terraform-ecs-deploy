resource "aws_codebuild_project" "promote_image" {
  name         = "test-project-cache"
  description  = "test_codebuild_project_cache"
  service_role = aws_iam_role.codepipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "063754174791"
    }
    environment_variable {
      name  = "VERSION"
      value = ""
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = ""
    }
    environment_variable {
      name  = "COMMIT_ID"
      value = ""
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("promote.yaml")
  }
}
