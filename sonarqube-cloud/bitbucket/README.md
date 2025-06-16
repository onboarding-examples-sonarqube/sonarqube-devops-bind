# SonarQube Cloud - Bitbucket Integration

This directory contains scripts for adding Bitbucket projects to SonarQube Cloud and establishing DevOps binding.

## Requirements

- SonarQube Cloud account
- Bitbucket account with admin privileges to the repositories
- Bitbucket App Password with appropriate permissions
- `curl` and `jq` installed on your system

## Configuration

1. Copy the configuration template from `../../common/config-template.sh` to this directory and rename it to `config.sh`
2. Edit `config.sh` and fill in the required values for your environment

## Available Scripts

- `create-project.sh`: Creates a new SonarQube Cloud project and binds it to Bitbucket
- `bind-existing-project.sh`: Binds an existing SonarQube Cloud project to Bitbucket
- `batch-import.sh`: Imports multiple Bitbucket repositories as SonarQube Cloud projects

## Usage

```bash
# Create a new project and bind to Bitbucket
./create-project.sh

# Bind existing project to Bitbucket
./bind-existing-project.sh --project-key=my-project

# Import multiple repositories
./batch-import.sh --workspace=myworkspace --repos-file=repositories.txt
```

## API Reference

SonarQube Cloud uses a unified API approach for all DevOps platforms. For Bitbucket integration, it uses:

- `POST /api/projects/create` - Create a new project
- `POST /api/alm_settings/create_binding` - Create ALM binding for the organization
- `POST /api/alm_settings/set_bitbucket_binding` - Bind a SonarQube project to Bitbucket
