# SonarQube DevOps Binding Scripts

This repository contains shell scripts for adding projects to SonarQube with DevOps platform bindings. The scripts are organized by SonarQube deployment type and DevOps platform.

## Repository Structure

```
├── sonarqube-server/     # Scripts for SonarQube Server instances
│   ├── github/          # Scripts for GitHub integration
│   ├── azure-devops/    # Scripts for Azure DevOps integration
│   ├── gitlab/         # Scripts for GitLab integration
│   └── bitbucket/      # Scripts for Bitbucket integration
├── sonarqube-cloud/      # Scripts for SonarQube Cloud instances
│   ├── github/          # Scripts for GitHub integration
│   ├── azure-devops/    # Scripts for Azure DevOps integration
│   ├── gitlab/         # Scripts for GitLab integration
│   └── bitbucket/      # Scripts for Bitbucket integration
└── common/             # Common utilities and shared scripts
```

## Overview

SonarQube supports integration with multiple DevOps platforms:
- GitHub
- Azure DevOps
- GitLab
- Bitbucket

### SonarQube Server vs SonarQube Cloud

- **SonarQube Server**: Self-hosted instance where different parameters might be needed for API calls depending on the DevOps platform.
- **SonarQube Cloud**: Uses the same API approach for all DevOps platforms.

## Usage

Each directory contains scripts with examples of how to create and bind SonarQube projects to specific DevOps platforms. See the README in each directory for platform-specific instructions.