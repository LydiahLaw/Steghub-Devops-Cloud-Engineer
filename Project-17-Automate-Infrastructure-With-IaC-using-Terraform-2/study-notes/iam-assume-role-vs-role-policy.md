# IAM: Assume Role Policy vs Role Policy

## Background — What an IAM Role Is

An IAM Role is an AWS identity with a set of permissions. Unlike an IAM user (which belongs to a person), a role is meant to be assumed temporarily adopted by a service, application, or another AWS account that needs to perform certain actions.

When an EC2 instance assumes a role, it gets temporary credentials (an access key, secret key, and session token) that it can use to call AWS APIs. Those credentials expire automatically, which is more secure than storing long-lived access keys on the instance.

Two separate policies govern how a role works: the **assume role policy** and the **role policy**. They answer completely different questions and live in different places.

---

## Assume Role Policy (Trust Policy)

**The question it answers:** *Who is allowed to assume this role?*

This policy is attached directly to the IAM Role itself as its trust relationship. It defines the trusted entity — the principal that is permitted to call `sts:AssumeRole` and take on the role's identity.

In Terraform, this is the `assume_role_policy` argument inside `aws_iam_role`:

```hcl
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
```

The `Principal` field is the key part. Here it says `"Service": "ec2.amazonaws.com"` meaning the EC2 service is trusted to assume this role. Other valid principals include:

- Another AWS account: `"AWS": "arn:aws:iam::123456789012:root"`
- A specific IAM user: `"AWS": "arn:aws:iam::123456789012:user/lydiah"`
- Another AWS service: `"Service": "lambda.amazonaws.com"`

Without a trust policy, a role is an empty shell it exists but nothing can use it. The trust policy is the first gate.

---

## Role Policy (Permission Policy)

**The question it answers:** *What is this role allowed to do?*

This is a standard IAM policy defining the actual permissions — what AWS actions can be performed, on which resources. It is created separately and then attached to the role.

In Terraform, this is a separate `aws_iam_policy` resource connected via `aws_iam_role_policy_attachment`:

```hcl
resource "aws_iam_policy" "policy" {
  name = "ec2_instance_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:Describe*"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.policy.arn
}
```

This grants the role the ability to describe EC2 resources. You can attach multiple policies to a single role AWS evaluates all of them together when deciding whether to allow or deny a request.

---

## The Core Difference

| | Assume Role Policy (Trust Policy) | Role Policy (Permission Policy) |
|---|---|---|
| **Question answered** | Who can use this role? | What can this role do? |
| **Attached to** | The role itself (trust relationship) | The role via policy attachment |
| **Contains** | Trusted principal (service, user, account) | AWS actions and resource ARNs |
| **AWS service used** | STS (Security Token Service) | IAM policy evaluation engine |
| **Without it** | Nobody can assume the role | The role has no permissions |

---

## How They Work Together

Both policies must be in place for a role to be useful:

1. **The trust policy** allows EC2 (`ec2.amazonaws.com`) to assume the role — AWS STS issues temporary credentials to the instance.
2. **The permission policy** defines what those credentials can actually do — in this case, `ec2:Describe*`.

If only the trust policy exists: EC2 can assume the role, but once it does, it has no permissions and cannot do anything.

If only the permission policy exists: the permissions are defined, but no entity is trusted to assume the role, so the credentials can never be obtained.

You need both, in the same way you need both a valid keycard (trust policy — you are allowed in) and the right clearance level (permission policy — here is what you can access once inside).

---

## Why This Matters in Practice

The separation of trust from permissions is what makes IAM roles composable and auditable.

You can attach the same permission policy to multiple roles — for example, a read-only S3 policy attached to a developer role, a CI/CD role, and a monitoring role each with different trust policies controlling who can assume them.

You can also scope the trust policy tightly for security. Instead of trusting all of EC2, you can restrict it to instances with a specific tag, or to a specific account, or to a federated identity provider. The trust policy is where you enforce the principle of least privilege at the identity level, and the permission policy is where you enforce it at the action level.

In cross-account access scenarios where one AWS account needs to act on resources in another the trust policy in the target account is what grants the source account permission to assume the role. The permission policy then controls what it can do after assuming it. This is the standard pattern for multi-account AWS architectures.
