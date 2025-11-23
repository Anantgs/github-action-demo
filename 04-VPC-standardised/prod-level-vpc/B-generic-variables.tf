
# AWS Region

variable "aws_region" {
  description = "This is the aws region that we gonna choose"
  type        = string
  default     = "us-east-1"
}

# Environment Variable

variable "environment" {
  description = "This is the environment variable"
  type        = string
  default     = "dev"
}

# Business Devision

variable "business_devision" {
  description = "This variable is used for business devision"
  type        = string
  default     = "HR-DEVISION"
}

