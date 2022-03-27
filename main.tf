terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "aws_codestarconnections_connection" "github" {
  arn = "arn:aws:codestar-connections:us-east-1:063754174791:connection/f82bad92-5580-4ef2-8ae7-21688ba9c04f"
}

# data "aws_region" "current" {
#   provider = aws.region
# }

data "aws_caller_identity" "current" {}


resource "aws_ecr_repository" "ecr" {
  name                 = "node-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "foopolicy" {
  repository = aws_ecr_repository.ecr.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_codebuild_project" "dockerbuild" {
  service_role = aws_iam_role.codepipeline_role.arn
  name         = "test"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    image           = "aws/codebuild/standard:5.0"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "node-app"
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "tf-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      namespace        = "SourceVariables"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = "ThrowsException/terraform-ecs-deploy"
        BranchName       = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName          = "test"
        EnvironmentVariables = <<EOF
          [{"name": "BRANCH", "value": "#{SourceVariables.BranchName}", "type": "PLAINTEXT"}]
        EOF
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = "default"
        ServiceName : aws_ecs_service.app.name
        FileName : "imagedefinitions.json"
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "cjo-codepipeline"
  acl    = "private"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "test-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codepipeline.amazonaws.com",
          "codebuild.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "s3:PutObject"
          ],
          "Resource" : [
            aws_s3_bucket.codepipeline_bucket.arn,
            aws_s3_bucket.codepipeline_bucket.arn
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*",
            "cloudformation:*",
            "iam:PassRole",
            "sns:Publish",
            "codestar-connections:*",
            "codebuild:*",
            "cloudwatch:*",
            "logs:*",
            "ecr:*",
            "ecs:*"
          ],
          "Resource" : "*"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "taskrole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "ecs-tasks.amazonaws.com"
            ]
          },
          "Action" : "sts:AssumeRole"
        }
      ]
  })

  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:GetObject"
          ],
          "Effect" : "Allow",
          "Resource" : ["arn:aws:s3:::prod-region-starport-layer-bucket/*"]
        },
        {
          "Action" : [
            "kms:*",
            "ssm:*",
            "s3:*",
            "secretsmanager:*"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "*"
          ]
        }
      ]
    })
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_ssm" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_kms" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.kms"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "sg-94b080e2",
  ]
  subnet_ids          = ["subnet-824b55e6", "subnet-88595ca7"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_s3" {
  vpc_id            = "vpc-fc8d1f87"
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = ["rtb-ce6de4b2", "rtb-9565ece9"]
}


resource "aws_ecs_task_definition" "app" {
  family = "app"
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "063754174791.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.ecr.name}:master"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ],
      secrets = [
        {
          "name" : "SECRET",
          "valueFrom" : "arn:aws:ssm:us-east-1:063754174791:parameter/ExampleParameter"
        }
      ]
    },
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.task.arn
}

resource "aws_lb" "app" {
  name               = "app"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-94b080e2"]
  subnets            = ["subnet-824b55e6", "subnet-88595ca7"]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name        = "app"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-fc8d1f87"

}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_service" "app" {
  name            = "app"
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = ["subnet-824b55e6", "subnet-88595ca7"]
    security_groups = ["sg-94b080e2"]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }
}
