# Terraform AWS HealthOmics Configuration

This repository contains Terraform configurations for setting up AWS HealthOmics resources, including S3 buckets, IAM users and policies, ECR repositories, and roles for a health omics service for use with 
DNAstack Workbench

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- AWS account with appropriate permissions
- AWS CLI configured with your credentials

## Files Overview

- `main.tf`: Defines the primary AWS resources, including S3 buckets, IAM users, policies, and ECR repositories.
- `outputs.tf`: Specifies the outputs for the Terraform configuration, such as the access key ID and secret access key.
- `terraform.tf`: Contains Terraform backend configuration and required providers.
- `variables.tf`: Defines the input variables used in the Terraform configuration.
- `data.tf`: Contains data sources for IAM policy documents.

## Variables

The following variables are defined in `variables.tf`:

- `region`: AWS region to create the resources in.
- `output_bucket_name`: Name of the S3 bucket to store output data.
- `workbench_service_account_name`: Name of the IAM user for the workbench service account.
- `health_omics_user_policy_name`: Name of the policy for the health omics user.
- `health_omics_service_policy_name`: Name of the policy for the health omics service.
- `health_omics_role_name`: Name of the IAM role for the health omics service.
- `docker_repositories`: A list of Docker repository names to create and attach the appropriate IAM policies to 

## Usage

1. **Clone the Repository**

    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```

2. **Initialize Terraform**

    ```bash
    terraform init
    ```

3. **Set Up Variables**

    Create a `terraform.tfvars` file or export environment variables to provide the necessary values for the variables defined in `variables.tf`. Example `terraform.tfvars`:

    ```hcl
    region = "us-west-2"
    output_bucket_name = "my-output-bucket"
    ```

4. **Plan the Deployment**

    ```bash
    terraform plan
    ```

    This command will show you the resources that Terraform will create or update.

5. **Apply the Configuration**

    ```bash
    terraform apply
    ```

    Type `yes` when prompted to confirm the creation of resources.

6. **Retrieve Outputs**

    After applying the configuration, you can retrieve the output values defined in `outputs.tf`:

    ```bash
    terraform output
    ```

    This will provide you with the access key ID and secret access key for the workbench service account, among other outputs.

## Cleaning Up

To destroy the resources created by this configuration, run:

```bash
terraform destroy
```

Type `yes` when prompted to confirm the destruction of resources.

## Notes

- Ensure that you have the necessary permissions to create and manage the specified AWS resources.
- Review and customize the IAM policies in `data.tf` to fit your security requirements.