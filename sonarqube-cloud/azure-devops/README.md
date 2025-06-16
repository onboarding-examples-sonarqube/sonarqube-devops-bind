# SonarQube Cloud - Azure DevOps Integration

This directory contains scripts for adding Azure DevOps projects to SonarQube Cloud and establishing DevOps binding.

## Requirements

- SonarQube Cloud account
- Azure DevOps account with admin privileges to the projects
- Azure DevOps Personal Access Token with appropriate permissions
- `curl` and `jq` installed on your system

## Configuration

1. Copy the configuration template from `../../common/config-template.sh` to this directory and rename it to `config.sh`
2. Edit `config.sh` and fill in the required values for your environment

## Available Scripts

- `create-project.sh`: Creates a new SonarQube Cloud project and binds it to Azure DevOps
- `bind-existing-project.sh`: Binds an existing SonarQube Cloud project to Azure DevOps
- `batch-import.sh`: Imports multiple Azure DevOps repositories as SonarQube Cloud projects

## Usage

```bash
# Create a new project and bind to Azure DevOps
./create-project.sh

# Bind existing project to Azure DevOps
./bind-existing-project.sh --project-key=my-project

# Import multiple repositories
./batch-import.sh --organization=myorg --project=myproject --repos-file=repositories.txt
```

## API Reference

SonarQube Cloud uses a unified API approach for all DevOps platforms. For Azure DevOps integration, it uses:

- `POST /api/projects/create` - Create a new project
- `POST /api/alm_settings/create_binding` - Create ALM binding for the organization
- `POST /api/alm_settings/set_azure_binding` - Bind a SonarQube project to Azure DevOps
