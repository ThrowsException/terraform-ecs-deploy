# Fargate Deployment with Terraform and Image promotion process

main.tf builds all the things necessary for a fargate deployment
promote.tf creates a codebuild job for tagging images


## Image promotion process

aws codebuild start-build --project-name test-project-cache --environment-variables-override name=VERSION,value=1,type=PLAINTEXT name=IMAGE_REPO_NAME,value=node-app,type=PLAINTEXT name=COMMIT_ID,value=latest,type=PLAINTEXT

