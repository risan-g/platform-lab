resource "aws_iam_user" "backup_agent" {
  name = "platform-lab-backup-agent"

  tags = {
    Project   = "platform-lab"
    ManagedBy = "OpenTofu"
    Purpose   = "offsite-database-backups"
  }
}

data "aws_iam_policy_document" "backup_agent" {
  statement {
    sid    = "ListBackupPrefix"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.backups.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "postgres",
        "postgres/*"
      ]
    }
  }

  statement {
    sid    = "ReadWriteBackupObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.backups.arn}/postgres/*"
    ]
  }
}

resource "aws_iam_user_policy" "backup_agent" {
  name   = "platform-lab-backup-access"
  user   = aws_iam_user.backup_agent.name
  policy = data.aws_iam_policy_document.backup_agent.json
}

output "backup_agent_user" {
  description = "IAM workload identity used by the homelab backup agent."
  value       = aws_iam_user.backup_agent.name
}
