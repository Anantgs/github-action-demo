# Terraform Destroy Workflow - Detailed Explanation

## Overview
This workflow allows you to safely destroy all Terraform-managed infrastructure through GitHub Actions with a manual confirmation step.

---

## Workflow Structure Breakdown

### 1. **Workflow Trigger (`on`)**

```yaml
on:
  workflow_dispatch:  # Manual trigger only
    inputs:
      confirm:
        description: 'Type "destroy" to confirm deletion of all infrastructure'
        required: true
        default: 'no'
```

**Explanation:**
- `workflow_dispatch`: This trigger allows the workflow to be run **manually** from the GitHub UI (Actions tab)
- Unlike `push` or `pull_request`, this workflow won't run automatically
- **Benefit**: Prevents accidental infrastructure deletion

**Input Variables:**
- `inputs`: Defines parameters that users must provide when triggering the workflow
- `confirm`: A text input field that appears in the GitHub UI
  - `description`: Helper text shown to the user
  - `required: true`: User must provide a value
  - `default: 'no'`: Pre-filled value (user must change it to "destroy")

**How to Access Input Values:**
```yaml
${{ github.event.inputs.confirm }}
```

---

### 2. **Environment Variables (`env`)**

```yaml
env:
  TF_VERSION: '1.6.0'
  AWS_REGION: 'us-east-1'
  WORKING_DIR: '04-VPC-standardised/prod-level-vpc'
```

**Purpose:** Define reusable variables available to all steps in the workflow

**Variables Defined:**
- `TF_VERSION`: Terraform version to install
- `AWS_REGION`: AWS region where resources are deployed
- `WORKING_DIR`: Path to the Terraform configuration files

**How to Use in Workflow:**
```yaml
${{ env.WORKING_DIR }}  # Evaluates to: 04-VPC-standardised/prod-level-vpc
${{ env.TF_VERSION }}   # Evaluates to: 1.6.0
```

---

### 3. **Job Configuration**

```yaml
jobs:
  terraform-destroy:
    name: 'Terraform Destroy'
    runs-on: ubuntu-latest
    
    permissions:
      id-token: write
      contents: read
```

**Breakdown:**
- `terraform-destroy`: Job identifier (internal name)
- `name`: Display name in GitHub UI
- `runs-on: ubuntu-latest`: Runs on GitHub-hosted Ubuntu runner
- `permissions`: 
  - `id-token: write`: Allows OIDC token generation (for AWS authentication)
  - `contents: read`: Allows reading repository code

---

## Step-by-Step Explanation

### **Step 1: Checkout Code**

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

**Purpose:** Downloads repository code to the runner
**Why First?** Must happen before accessing any files (including WORKING_DIR)

---

### **Step 2: Verify Destroy Confirmation**

```yaml
- name: Verify Destroy Confirmation
  run: |
    if [ "${{ github.event.inputs.confirm }}" != "destroy" ]; then
      echo "❌ Destroy not confirmed. You must type 'destroy' to proceed."
      exit 1
    fi
    echo "✅ Destroy confirmed. Proceeding with infrastructure deletion..."
```

**Purpose:** Safety check to prevent accidental destruction

**Logic:**
1. Checks if user typed exactly "destroy"
2. If not, prints error and exits with code 1 (fails the workflow)
3. If confirmed, proceeds to next steps

**Parameters Used:**
- `${{ github.event.inputs.confirm }}`: Accesses the input variable from workflow trigger
- `exit 1`: Stops workflow execution with failure status

---

### **Step 3: Configure AWS Credentials**

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

**Purpose:** Authenticates with AWS to allow Terraform to destroy resources

**Parameters (`with`):**
- `aws-access-key-id`: Retrieved from GitHub Secrets (encrypted storage)
- `aws-secret-access-key`: Retrieved from GitHub Secrets
- `aws-region`: Uses the environment variable defined earlier

**How Secrets Work:**
- Stored in: Repository Settings → Secrets and variables → Actions
- Accessed via: `${{ secrets.SECRET_NAME }}`
- Never printed in logs (GitHub masks them)

---

### **Step 4: Setup Terraform**

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: ${{ env.TF_VERSION }}
```

**Purpose:** Installs Terraform CLI on the runner

**Parameters:**
- `terraform_version`: Installs version 1.6.0 (from env variable)

---

### **Step 5: Terraform Init**

```yaml
- name: Terraform Init
  id: init
  working-directory: ${{ env.WORKING_DIR }}
  run: terraform init -backend-config="profile="
```

**Purpose:** Initializes Terraform and configures S3 backend

**Key Concepts:**

**1. `working-directory`:**
- Changes to specified directory before running the command
- Why? Terraform files are in `04-VPC-standardised/prod-level-vpc`
- Without this, Terraform won't find configuration files

**How it works:**
```bash
# Equivalent to:
cd 04-VPC-standardised/prod-level-vpc
terraform init -backend-config="profile="
```

**2. `id: init`:**
- Assigns an identifier to this step
- Can reference outputs: `${{ steps.init.outputs.stdout }}`

**3. `-backend-config="profile="`:**
- Overrides the `profile = "kd"` setting in backend configuration
- Empty profile means use AWS credentials from environment (set in Step 3)
- Necessary because GitHub Actions doesn't have local AWS profile

---

### **Step 6: Terraform Plan Destroy**

```yaml
- name: Terraform Plan Destroy
  id: plan
  working-directory: ${{ env.WORKING_DIR }}
  run: terraform plan -destroy -no-color -out=destroy.tfplan
```

**Purpose:** Creates an execution plan for destroying all resources

**Parameters Explained:**
- `-destroy`: Creates a plan to destroy all resources (instead of create/update)
- `-no-color`: Removes ANSI color codes (makes logs cleaner)
- `-out=destroy.tfplan`: Saves plan to a file for next step

**Output:** Shows what will be destroyed (e.g., 25 resources to destroy)

---

### **Step 7: Terraform Destroy**

```yaml
- name: Terraform Destroy
  working-directory: ${{ env.WORKING_DIR }}
  run: terraform apply -auto-approve destroy.tfplan
```

**Purpose:** Executes the destroy plan

**Parameters:**
- `-auto-approve`: Skips "yes/no" confirmation (already confirmed in Step 2)
- `destroy.tfplan`: Uses the plan file from previous step

**What Happens:**
1. Deletes VPC
2. Deletes subnets (public, private, database)
3. Deletes NAT Gateway
4. Deletes Internet Gateway
5. Deletes route tables and associations
6. Deletes security groups
7. Updates S3 state file to empty state

---

### **Step 8: Confirm Destruction**

```yaml
- name: Confirm Destruction
  run: echo "🗑️ Infrastructure has been destroyed successfully!"
```

**Purpose:** Prints success message

---

## Key Concepts Summary

### **1. Working Directory**
```yaml
working-directory: ${{ env.WORKING_DIR }}
```
- Changes the current directory before executing commands
- Must be set for each Terraform step
- Without it, GitHub Actions runs commands from repository root

### **2. Input Variables**
```yaml
inputs:
  confirm:
    description: 'Type "destroy" to confirm'
    required: true
    default: 'no'
```
- Defined in `workflow_dispatch` trigger
- Appears as form fields in GitHub UI
- Accessed via: `${{ github.event.inputs.confirm }}`

### **3. Environment Variables**
```yaml
env:
  WORKING_DIR: '04-VPC-standardised/prod-level-vpc'
```
- Defined once, used everywhere
- Accessed via: `${{ env.VARIABLE_NAME }}`
- Can be defined at workflow, job, or step level

### **4. Parameters (`with`)**
```yaml
uses: some-action@v1
with:
  parameter1: value1
  parameter2: value2
```
- Used to pass inputs to GitHub Actions
- Different for each action (check action's documentation)
- Common examples: version numbers, credentials, paths

### **5. Secrets**
```yaml
${{ secrets.AWS_ACCESS_KEY_ID }}
```
- Encrypted storage for sensitive data
- Set in: Repository Settings → Secrets
- Never exposed in logs
- Accessed only via `${{ secrets.NAME }}`

---

## How to Use This Workflow

### **From GitHub UI:**

1. Navigate to: `https://github.com/Anantgs/github-action-demo/actions`
2. Click: **Terraform Destroy VPC** (left sidebar)
3. Click: **Run workflow** button (top right)
4. In the dropdown:
   - Branch: `master`
   - Confirm field: Type **`destroy`** (exactly)
5. Click: **Run workflow** (green button)

### **What Happens:**

```
✅ Checkout code
✅ Verify confirmation (if you typed "destroy")
✅ Configure AWS credentials
✅ Install Terraform
✅ Initialize with S3 backend
✅ Create destroy plan (shows resources to delete)
✅ Execute destroy (deletes all resources)
✅ Print success message
```

---

## Comparison: Deploy vs Destroy Workflow

| Feature | Deploy Workflow | Destroy Workflow |
|---------|----------------|------------------|
| **Trigger** | Automatic (on push) | Manual only |
| **Confirmation** | None | Required ("destroy") |
| **Safety** | Low risk (creates) | High risk (deletes) |
| **Command** | `terraform apply` | `terraform apply destroy.tfplan` |
| **Use Case** | CI/CD automation | Cleanup/teardown |

---

## Best Practices Implemented

1. ✅ **Manual trigger only** - Prevents accidental runs
2. ✅ **Confirmation required** - Must type "destroy"
3. ✅ **Plan before destroy** - Review what will be deleted
4. ✅ **S3 state backend** - Ensures consistent state
5. ✅ **Working directory specified** - Clear file organization
6. ✅ **Secrets for credentials** - Secure authentication

---

## Troubleshooting

### **Error: "No such file or directory"**
**Cause:** `working-directory` set before checkout
**Fix:** Ensure `checkout` step comes first

### **Error: "Destroy not confirmed"**
**Cause:** Didn't type "destroy" exactly
**Fix:** Type lowercase "destroy" in input field

### **Error: "Backend initialization failed"**
**Cause:** S3 bucket doesn't exist or no permissions
**Fix:** Verify S3 bucket exists and AWS credentials are valid

---

## Additional Resources

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Terraform Destroy Command](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)
