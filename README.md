# Terraform AWS Automation Repository

This repository contains a practical Terraform learning path and a more complete AWS infrastructure example for provisioning an Amazon EKS cluster. It is organized to help you move from foundational Terraform concepts to reusable, team-friendly infrastructure patterns.

## Repository Goals

- Introduce core Terraform concepts for AWS infrastructure
- Demonstrate infrastructure as code best practices
- Show how to structure Terraform projects for learning and reuse
- Provide an example of a production-style EKS deployment workflow

## Repository Structure

- [Terraform_Basics](Terraform_Basics) – beginner-friendly Terraform labs covering fundamentals, VPCs, variables, remote state, and modules
- [Terraform_EKS_Cluster](Terraform_EKS_Cluster) – a more complete example for building a VPC and an EKS cluster with remote state and modular design

## Prerequisites

Before using these examples, make sure you have:

- Terraform CLI installed and configured
- AWS CLI installed and authenticated
- An AWS account with sufficient permissions
- kubectl installed for the EKS section

## Recommended Learning Path

1. Start with [Terraform_Basics/README.md](Terraform_Basics/README.md) to understand Terraform basics.
2. Review the VPC and module examples in the basics section.
3. Move to [Terraform_EKS_Cluster/README.md](Terraform_EKS_Cluster/README.md) for the EKS deployment workflow.

## Recommended Practices

- Use environment-specific variable files such as `.tfvars` for different deployments
- Keep state secure by using a remote backend such as S3 with state locking
- Avoid hard-coding secrets; use IAM roles, environment variables, or secure secret stores
- Validate and plan changes before applying them

## Getting Started

From the repository root:

```bash
cd Terraform_Basics
# Follow the lab flow in the subdirectories
```

For the EKS example:

```bash
cd Terraform_EKS_Cluster
# Follow the instructions in the project README
```

## Notes

These examples are designed for learning and can be adapted for real-world environments. Review each module carefully and adjust variables, IAM permissions, networking, and backend configuration to fit your environment.

