# SonarQube Server - GitHub Integration

This directory contains scripts for adding GitHub projects to a self-hosted SonarQube Server instance and establishing DevOps binding.

## Requirements

- SonarQube Server instance with Developer Edition or higher
- GitHub account with admin privileges to the repositories
- GitHub Personal Access Token with appropriate permissions
- `curl` and `jq` installed on your system

## Configuration

1. Copy the configuration template from `../../common/config-template.sh` to this directory and rename it to `config.sh`
2. Edit `config.sh` and fill in the required values for your environment

## Available Scripts

- `create-project.sh`: Creates a new SonarQube project and binds it to GitHub
- `bind-existing-project.sh`: Binds an existing SonarQube project to GitHub
- `batch-import.sh`: Imports multiple GitHub repositories as SonarQube projects

## Usage

```bash
# Create a new project and bind to GitHub
./create-project.sh

# Bind existing project to GitHub
./bind-existing-project.sh --project-key=my-project

# Import multiple repositories
./batch-import.sh --org=myorg --repos-file=repositories.txt
```

## API Reference

SonarQube Server with GitHub integration uses the following API endpoints:

- `POST /api/projects/create` - Create a new project
- `POST /api/alm_settings/set_github_binding` - Bind a SonarQube project to GitHub
- `POST /api/project_branches/rename` - Rename the main branch if needed
