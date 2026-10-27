resource "aws_ecr_repository" "tooling_app" {
  name                 = "tooling-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # lets terraform destroy remove it even with images inside

  image_scanning_configuration {
    scan_on_push = true
  }
}
