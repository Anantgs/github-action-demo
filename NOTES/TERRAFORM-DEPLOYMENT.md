# Terraform Deployment with GitHub Actions

## 🚀 Quick Start

### Prerequisites
- GitHub repository with Terraform code
- AWS Account with appropriate permissions
- GitHub repository secrets configured

## 📋 Setup Instructions

### Step 1: Configure GitHub Secrets

Go to your GitHub repository: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

### Step 2: Update Terraform Backend (Optional but Recommended)

Create `backend.tf` in your Terraform directory:

```terraform
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

### Step 3: Remove Local Profile from Terraform

The workflow doesn't use local AWS profiles. Update `A-versions.tf`:

```terraform
provider "aws" {
  region  = var.aws_region
  # Remove or comment out: profile = "default"
}
```

### Step 4: Deploy

#### Manual Trigger
1. Go to **Actions** tab in GitHub
2. Select **Terraform Deploy VPC** workflow
3. Click **Run workflow**
4. Select branch and click **Run workflow**

#### Automatic Trigger
- **Push to main**: Automatically runs `terraform apply`
- **Pull Request**: Runs `terraform plan` and comments on PR

## 🔄 Workflow Behavior

### On Pull Request
- ✅ Terraform format check
- ✅ Terraform init
- ✅ Terraform validate
- ✅ Terraform plan
- 📝 Posts plan results as PR comment
- ❌ Does NOT apply changes

### On Push to Main
- ✅ Terraform format check
- ✅ Terraform init
- ✅ Terraform validate
- ✅ Terraform plan
- ✅ **Terraform apply** (auto-approved)
- 📊 Shows outputs

### Manual Trigger (workflow_dispatch)
- Same as push to main
- Can be triggered from any branch

## 🛡️ Security Best Practices

### Option 1: AWS Access Keys (Current Setup)
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

### Option 2: OIDC (Recommended for Production)

1. **Create OIDC Provider in AWS**
```bash
# In AWS Console: IAM → Identity Providers → Add Provider
Provider Type: OpenID Connect
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

2. **Create IAM Role for GitHub Actions**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

3. **Update Workflow**
```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    role-session-name: GitHubActions-TerraformDeploy
    aws-region: us-east-1
```

4. **Add Secret**
- Secret Name: `AWS_ROLE_ARN`
- Value: `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole`

## 📁 Project Structure

```
github-action-demo/
├── .github/
│   └── workflows/
│       ├── github-actions-demo.yml    # Demo workflow
│       └── terraform-deploy.yml       # Terraform deployment
├── 04-VPC-standardised/
│   └── prod-level-vpc/
│       ├── A-versions.tf
│       ├── B-generic-variables.tf
│       ├── C-local-values.tf
│       ├── D-vpc-variable.tf
│       ├── E-vpc-module.tf
│       └── F-vpc-output.tf
└── NOTES/
    └── DEPLOYMENT.md                  # This file
```

## 🎯 Common Commands

### Local Testing (Before Pushing)
```bash
cd 04-VPC-standardised/prod-level-vpc

# Format
terraform fmt

# Initialize
terraform init

# Validate
terraform validate

# Plan
terraform plan

# Apply (manual)
terraform apply
```

### Monitoring GitHub Actions
```bash
# View workflow runs
gh run list --workflow=terraform-deploy.yml

# View specific run logs
gh run view <run-id> --log

# Watch live
gh run watch
```

## 🐛 Troubleshooting

### Error: "Error configuring AWS credentials"
- Check GitHub secrets are set correctly
- Verify AWS credentials have necessary permissions
- Check region is correct

### Error: "Backend initialization required"
- Ensure S3 bucket exists (if using remote backend)
- Check backend configuration is correct
- Verify AWS credentials have S3 access

### Error: "Terraform fmt failed"
- Run `terraform fmt -recursive` locally
- Commit formatted files
- Push again

### Error: "Resource already exists"
- Check if resources were created manually
- Import existing resources: `terraform import`
- Or destroy and recreate

## 📊 Monitoring & Outputs

After successful apply, the workflow shows outputs:
```
Outputs:

vpc_id = "vpc-abc123"
public_subnets = ["subnet-123", "subnet-456"]
private_subnets = ["subnet-789", "subnet-012"]
```

## 🔄 Rollback Strategy

### If apply fails:
1. Check workflow logs
2. Fix issues in code
3. Create PR with fixes
4. Review plan in PR comments
5. Merge to trigger apply

### Emergency rollback:
```bash
# Locally
git revert <commit-hash>
git push origin main

# Or manually
terraform state pull > backup.tfstate
# Make manual changes in AWS
terraform refresh
terraform plan
terraform apply
```

## 🎓 Next Steps

1. **Add Terraform State Backend** for team collaboration
2. **Set up Branch Protection** to require PR reviews
3. **Add Cost Estimation** using Infracost
4. **Set up Notifications** (Slack, Teams, Email)
5. **Add Security Scanning** (tfsec, Checkov)
6. **Implement Drift Detection** (scheduled runs)

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [AWS OIDC Setup](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
