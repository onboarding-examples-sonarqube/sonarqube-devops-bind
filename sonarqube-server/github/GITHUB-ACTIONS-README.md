# SonarQube GitHub Actions Integration

This document explains how to use the simplified integration script (`github-action.sh`) to automatically add GitHub repositories to SonarQube Server in a CI/CD environment.

## Overview

The `github-action.sh` script is designed for GitHub Actions and other CI/CD platforms. It:

1. Checks if the repository exists in SonarQube's GitHub integration
2. Checks if the repository is already bound to a SonarQube project
3. Creates a new SonarQube project and binding if needed
4. Sets outputs that can be used in subsequent steps

## Prerequisites

- SonarQube Server with GitHub integration already configured
- SonarQube authentication token with appropriate permissions
- GitHub repository accessible to the configured SonarQube GitHub integration

## Usage in GitHub Actions

1. Store the following secrets in your GitHub repository:
   - `SONAR_HOST_URL`: Your SonarQube server URL
   - `SONAR_TOKEN`: Authentication token for SonarQube
   - `SONAR_ALM_KEY`: ALM Setting key for GitHub integration in SonarQube

2. Add the workflow file `.github/workflows/sonarqube-integration.yml` to your repository

3. The workflow will create and bind the repository to SonarQube when triggered

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SONAR_HOST_URL` | Yes | - | SonarQube server URL |
| `SONAR_TOKEN` | Yes | - | SonarQube authentication token |
| `SONAR_ALM_KEY` | Yes | - | SonarQube ALM Setting key for GitHub integration |
| `GITHUB_REPOSITORY` | Yes | From GitHub | GitHub repository (owner/repo format) |
| `SONAR_PROJECT_KEY` | No | {owner}_{repo_name} | SonarQube project key |
| `SONAR_PROJECT_NAME` | No | {repo_name} | SonarQube project name |
| `MONOREPO` | No | false | Set to "true" if repository is a monorepo |

## Outputs

- `sonar_project_key`: The SonarQube project key (either created or existing)

## Direct Usage

You can also use the script directly:

```bash
# Download the script
curl -s https://raw.githubusercontent.com/your-org/sonarqube-devops-bind/main/sonarqube-server/github/github-action.sh -o sonarqube-integration.sh
chmod +x sonarqube-integration.sh

# Set the required environment variables
export SONAR_HOST_URL="https://sonarqube.example.com"
export SONAR_TOKEN="your-sonarqube-token"
export SONAR_ALM_KEY="your-github-integration-key"
export GITHUB_REPOSITORY="owner/repo"

# Optional: customize project key and name
export SONAR_PROJECT_KEY="custom-project-key"
export SONAR_PROJECT_NAME="Custom Project Name"

# Run the script
./sonarqube-integration.sh
```

## Notes

- The script will exit with a non-zero status code if there's an error
- If the repository is already bound to a SonarQube project, the script will use the existing binding
- For monorepos (repositories with multiple projects), set `MONOREPO=true`
