#!/bin/bash
# Simple script to add GitHub repository to SonarQube Server via GitHub Actions
# Automatically detects if project already exists and creates binding if needed

# Required environment variables:
# SONAR_HOST_URL - SonarQube server URL
# SONAR_TOKEN - SonarQube authentication token
# SONAR_ALM_KEY - SonarQube ALM Setting key for GitHub integration
# GITHUB_REPOSITORY - GitHub repository (owner/repo format) - available by default in GitHub Actions
# SONAR_PROJECT_KEY - SonarQube project key (default: derived from repository name)
# SONAR_PROJECT_NAME - SonarQube project name (default: repository name)

set -e # Exit on error

# --- Configuration ---
SONAR_HOST_URL=${SONAR_HOST_URL:?'SONAR_HOST_URL is required'}
SONAR_TOKEN=${SONAR_TOKEN:?'SONAR_TOKEN is required'}
SONAR_ALM_KEY=${SONAR_ALM_KEY:?'SONAR_ALM_KEY is required'}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:?'GITHUB_REPOSITORY is required'}

# Parse GitHub repository parts
REPO_OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 1)
REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)

# Set project key and name if not provided
SONAR_PROJECT_KEY=${SONAR_PROJECT_KEY:-"${REPO_OWNER}_${REPO_NAME}"}
SONAR_PROJECT_NAME=${SONAR_PROJECT_NAME:-"$REPO_NAME"}
MONOREPO=${MONOREPO:-"false"} # Set to true if repository is a monorepo

echo "SonarQube Integration: Adding repository $GITHUB_REPOSITORY to SonarQube"
echo "Project Key: $SONAR_PROJECT_KEY"
echo "Project Name: $SONAR_PROJECT_NAME"

# --- Fetch DevOps platform settings ---
echo "Fetching DevOps platform settings from SonarQube"
DOP_SETTINGS_RESPONSE=$(curl -s -u "$SONAR_TOKEN:" \
  "${SONAR_HOST_URL}/api/v2/dop-translation/dop-settings")

# Find the DevOps platform setting ID for the given ALM setting key
DOP_SETTING_ID=$(echo "$DOP_SETTINGS_RESPONSE" | grep -o "\"id\":\"[^\"]*\",\"type\":\"github\",\"key\":\"$SONAR_ALM_KEY\"" | grep -o "\"id\":\"[^\"]*\"" | cut -d '"' -f 4)

if [ -z "$DOP_SETTING_ID" ]; then
  echo "Error: No GitHub DevOps platform setting found with key: $SONAR_ALM_KEY"
  exit 1
fi

echo "Found DevOps platform setting ID: $DOP_SETTING_ID"

# --- Check if the repository exists in GitHub integration ---
echo "Checking if repository $GITHUB_REPOSITORY exists in GitHub integration"
REPOS_RESPONSE=$(curl -s -u "$SONAR_TOKEN:" \
  "${SONAR_HOST_URL}/api/alm_integrations/list_github_repositories?almSetting=$SONAR_ALM_KEY&organization=$REPO_OWNER")

# Check if repository exists and if it's already bound
REPO_EXISTS=$(echo "$REPOS_RESPONSE" | grep -c "\"key\":\"$GITHUB_REPOSITORY\"" || true)
ALREADY_BOUND=$(echo "$REPOS_RESPONSE" | grep -c "\"key\":\"$GITHUB_REPOSITORY\".*\"sqProjectKey\"" || true)
EXISTING_PROJECT_KEY=$(echo "$REPOS_RESPONSE" | grep -o "\"key\":\"$GITHUB_REPOSITORY\".*\"sqProjectKey\":\"[^\"]*\"" | grep -o "\"sqProjectKey\":\"[^\"]*\"" | cut -d '"' -f 4 || echo "")

if [ "$REPO_EXISTS" -eq 0 ]; then
  echo "Error: Repository $GITHUB_REPOSITORY not found in GitHub integration with ALM setting: $SONAR_ALM_KEY"
  exit 1
fi

# --- Create binding or use existing ---
if [ "$ALREADY_BOUND" -ne 0 ]; then
  echo "Repository $GITHUB_REPOSITORY is already bound to SonarQube project: $EXISTING_PROJECT_KEY"
  echo "Using existing binding"
  
  # Set project key to existing one for output
  SONAR_PROJECT_KEY=$EXISTING_PROJECT_KEY
else
  echo "Creating SonarQube project and binding to GitHub repository: $GITHUB_REPOSITORY"
  
  # Create project and binding
  CREATE_BINDING_RESPONSE=$(curl -s -X POST -u "$SONAR_TOKEN:" \
    -H "Content-Type: application/json" \
    "${SONAR_HOST_URL}/api/v2/dop-translation/bound-projects" \
    -d "{\"projectKey\":\"$SONAR_PROJECT_KEY\",\"projectName\":\"$SONAR_PROJECT_NAME\",\"devOpsPlatformSettingId\":\"$DOP_SETTING_ID\",\"repositoryIdentifier\":\"$GITHUB_REPOSITORY\",\"monorepo\":$MONOREPO}")
  
  # Check if there was an error
  if echo "$CREATE_BINDING_RESPONSE" | grep -q "error"; then
    echo "Error creating project and binding:"
    echo "$CREATE_BINDING_RESPONSE"
    exit 1
  fi
  
  echo "Successfully created project $SONAR_PROJECT_KEY and bound to GitHub repository: $GITHUB_REPOSITORY"
fi

# Set output for GitHub Actions
echo "sonar_project_key=$SONAR_PROJECT_KEY" >> $GITHUB_OUTPUT

echo "SonarQube integration complete. Your SonarQube project key is: $SONAR_PROJECT_KEY"
