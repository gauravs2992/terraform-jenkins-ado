# Jenkins on Azure with Terraform and Azure DevOps

The Azure DevOps pipeline provisions an Ubuntu 24.04 VM, installs Jenkins, and then installs these Python packages into a virtual environment available to Jenkins jobs:

- `python-hcl2` for parsing HCL
- `azure-identity` and `azure-mgmt-resource` for Azure SDK authentication and resource management

The VM exposes SSH and Jenkins HTTP (port 8080) only to the configured administrator CIDR. Jenkins is served directly over HTTP; use a TLS-terminating reverse proxy or a private network for production deployments.

## Prerequisites

1. An enabled Azure Resource Manager service connection named `Gaurav Sharma` in Azure DevOps, with permission to create the deployment resources (Contributor at the target subscription or resource-group scope). The pipeline references the service connection by its literal name because Azure DevOps does not resolve runtime variables for service connection inputs. If your connection has a different name, replace the `azureSubscription` value in `azure-pipelines.yml` with that exact name. In **Project settings > Service connections**, authorize the connection for this pipeline (or enable access for all pipelines).
2. A Terraform state storage account and blob container in Azure. The service connection identity needs `Storage Blob Data Contributor` on the state container. Create these once before running the pipeline, for example:

   ```bash
   az group create --name <state-resource-group> --location eastus
   az storage account create \
     --name <globally-unique-storage-account-name> \
     --resource-group <state-resource-group> \
     --location eastus \
     --sku Standard_LRS \
     --allow-blob-public-access false \
     --min-tls-version TLS1_2
   az storage container create \
     --name tfstate \
     --account-name <globally-unique-storage-account-name> \
     --auth-mode login
   ```

   Assign the service connection identity `Storage Blob Data Contributor` on the storage account or container.
3. Configure these Azure DevOps pipeline variables:

   | Variable | Secret? | Value |
   | --- | --- | --- |
   | `TF_STATE_RESOURCE_GROUP` | No | Resource group containing the Terraform state account |
   | `TF_STATE_STORAGE_ACCOUNT` | No | Name of the Terraform state storage account |
   | `TF_STATE_CONTAINER` | No | Blob container for Terraform state (for example, `tfstate`) |
   | `JENKINS_ADMIN_SSH_PUBLIC_KEY` | No | Public key for VM administrator SSH access |
   | `JENKINS_ADMIN_CIDR` | No | Trusted IPv4 CIDR allowed to access SSH and Jenkins, for example `203.0.113.10/32` |

   Do not use `0.0.0.0/0` for the administrator CIDR. The public key is not a secret, but can be stored as a secret pipeline variable if preferred.
4. Ensure the Azure DevOps agent can reach Azure and HashiCorp's Terraform release host.

## Run

Commit or merge the pipeline to `main` to deploy. The pipeline pins Terraform, verifies the downloaded archive checksum, initializes the Azure Blob remote backend, validates the configuration, and applies the plan. Re-running it updates the existing deployment using the same remote state.

After provisioning, the Terraform outputs include the Jenkins URL, public IP, and SSH command. Open the URL from the configured CIDR. Retrieve Jenkins' initial setup password over SSH:

```bash
ssh jenkinsadmin@<jenkins-public-ip> \
  'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

Cloud-init completes the Jenkins and library installation after Azure creates the VM; allow a few minutes for first boot. The Python libraries are installed at `/opt/jenkins-python/venv`. Jenkins jobs inherit this virtual environment in `PATH`; for example, use `python -c 'import hcl2, azure.identity, azure.mgmt.resource'` in a Jenkins shell step.

VM creation incurs Azure charges. To remove the deployment, run `terraform destroy` from a trusted environment initialized with the same remote backend and set the same `TF_VAR_admin_ssh_public_key` and `TF_VAR_admin_source_cidr` values.
