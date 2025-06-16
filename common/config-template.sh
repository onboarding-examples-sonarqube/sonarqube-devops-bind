#!/bin/bash
# Configuration template for SonarQube scripts
# Copy this file and rename it to config.sh in your specific platform directory
# Then fill in the values for your environment

# SonarQube instance details
SONARQUBE_URL=""           # URL of your SonarQube instance (e.g., https://sonarqube.example.com)
SONARQUBE_TOKEN=""         # Authentication token for SonarQube API

# Project details
PROJECT_KEY=""             # Unique key for the project in SonarQube
PROJECT_NAME=""            # Display name for the project in SonarQube
PROJECT_VISIBILITY="private" # Project visibility: private or public

# DevOps platform connection details
DEVOPS_PLATFORM=""         # github, azure-devops, gitlab, or bitbucket
DEVOPS_URL=""              # URL of your DevOps platform
DEVOPS_TOKEN=""            # Authentication token for DevOps platform API

# Repository details
REPOSITORY_NAME=""         # Name of the repository
REPOSITORY_OWNER=""        # Owner/Organization of the repository
REPOSITORY_URL=""          # Full URL to the repository

# Additional configuration
MAIN_BRANCH="main"         # Main branch name (e.g., main, master)
LANGUAGE=""                # Main language of the project
