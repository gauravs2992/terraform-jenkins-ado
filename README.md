# Jenkins on Azure with Terraform and Azure DevOps

The Azure DevOps pipeline provisions an Ubuntu 24.04 VM, installs Jenkins, and then installs these Python packages into a virtual environment available to Jenkins jobs:

- `python-hcl2` for parsing HCL
- `azure-identity` and `azure-mgmt-resource` for Azure SDK authentication and resource management

The VM exposes SSH and Jenkins HTTP (port 8080) only to the configured administrator CIDR. Jenkins is served directly over HTTP; use a TLS-terminating reverse proxy or a private network for production deployments.

## Prerequisites

1. An enabled Azure Resource Manager service connection named `Gaurav Sharma` in Azure DevOps, with permission to create resource groups and resources at subscription scope (for example, Contributor). Use workload identity federation (recommended) or a service principal with a client secret. The pipeline passes those service-connection credentials directly to Terraform; it does not use Azure CLI user authentication. It references the service connection by its literal name because Azure DevOps does not resolve runtime variables for service-connection inputs. If your connection has a different name, replace the `azureSubscription` value in `azure-pipelines.yml` with that exact name. In **Project settings > Service connections**, authorize the connection for this pipeline (or enable access for all pipelines).
2. Configure these Azure DevOps pipeline variables:

   | Variable | Secret? | Value |
   | --- | --- | --- |
   | `TF_STATE_RESOURCE_GROUP` | No | Resource group to create/use for the Terraform state account |
   | `TF_STATE_STORAGE_ACCOUNT` | No | Globally unique storage account name (3-24 lowercase letters or numbers) |
   | `TF_STATE_CONTAINER` | No | Blob container to create/use for Terraform state (for example, `tfstate`) |
   | `JENKINS_ADMIN_PASSWORD` | **Yes** | Strong Linux administrator password (12-72 characters; use at least three character types) |
   | `JENKINS_ADMIN_CIDR` | No | Trusted IPv4 CIDR allowed to access SSH and Jenkins; use your exact public IP with `/32`, or the network address for a subnet |

   Mark `JENKINS_ADMIN_PASSWORD` as secret in Azure DevOps. Password-based SSH is enabled, but access is restricted to the configured CIDR; do not use `0.0.0.0/0`. Use canonical CIDR notation: for a single IP use `<your-public-ip>/32`; for a subnet use its network address (for example, `203.0.113.0/24`, not `203.0.113.10/24`). Terraform stores the VM password in its state, so protect the state storage account and limit access to it.
   The pipeline creates the state resource group, storage account, and private blob container if they do not already exist. The storage account is created in `eastus` by default; change `terraformStateLocation` in `azure-pipelines.yml` to use another region. The service connection needs permission to create resource groups and storage accounts and retrieve a storage account key. The backend uses that key at runtime, masked in logs, so restrict service-connection and state-account access.
3. Ensure the Azure DevOps agent can reach Azure and HashiCorp's Terraform release host.

## Run

Commit or merge the pipeline to `main` to deploy. The pipeline pins Terraform, verifies the downloaded archive checksum, creates the remote state resources before initializing the Azure Blob backend, validates the configuration, and applies the plan. It retrieves the storage account key at runtime and masks it in pipeline logs. Re-running it reuses the same state container and updates the deployment. The VM uses Canonical's Ubuntu 24.04 LTS marketplace image.

After provisioning, the Terraform outputs include the Jenkins URL, public IP, and SSH command. Open the URL from the configured CIDR. Connect over SSH and enter the Linux administrator password when prompted:

```bash
ssh jenkinsadmin@<jenkins-public-ip>
```

Once connected, retrieve Jenkins' initial setup password with `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`. Cloud-init completes the Jenkins and library installation after Azure creates the VM; allow a few minutes for first boot. The Python libraries are installed at `/opt/jenkins-python/venv`. Jenkins jobs inherit this virtual environment in `PATH`; for example, use `python -c 'import hcl2, azure.identity, azure.mgmt.resource'` in a Jenkins shell step.

VM creation incurs Azure charges. To remove the deployment, run `terraform destroy` from a trusted environment initialized with the same remote backend and set the same `TF_VAR_admin_password` and `TF_VAR_admin_source_cidr` values.

Switching an already-deployed VM from SSH-key-only to password authentication may require Terraform to replace the VM, causing downtime and loss of data stored only on its OS disk. Review the pipeline plan and back up any required data before approving this change.
