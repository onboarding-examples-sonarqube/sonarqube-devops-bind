# SonarQube Integration - Simple Commands for GitHub Actions

Below are simple commands that can be directly added to a GitHub Actions workflow step to add a repository to SonarQube Server.

## Prerequisites

- SonarQube Server with GitHub integration already configured
- SonarQube authentication token with appropriate permissions
- Access to GitHub repository secrets

## Basic GitHub Actions Usage

Add this to your GitHub Actions workflow file:

```yaml
- name: Add Repository to SonarQube
  env:
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_ALM_KEY: ${{ secrets.SONAR_ALM_KEY }}
  run: |
    # Get DevOps platform setting ID from ALM key
    DOP_SETTING_ID=$(curl -s -u "$SONAR_TOKEN:" \
      "${SONAR_HOST_URL}/api/v2/dop-translation/dop-settings" | \
      grep -o "\"id\":\"[^\"]*\",\"type\":\"github\",\"key\":\"$SONAR_ALM_KEY\"" | \
      grep -o "\"id\":\"[^\"]*\"" | cut -d '"' -f 4)
    
    # Replace spaces in project name with underscores
    REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)
    PROJECT_KEY="${GITHUB_REPOSITORY_OWNER}_${REPO_NAME}"
    
    # Create project and bind to GitHub repository  
    curl -X POST -u "$SONAR_TOKEN:" \
      -H "Content-Type: application/json" \
      "${SONAR_HOST_URL}/api/v2/dop-translation/bound-projects" \
      -d "{\"projectKey\":\"$PROJECT_KEY\",\"projectName\":\"$REPO_NAME\",\"devOpsPlatformSettingId\":\"$DOP_SETTING_ID\",\"repositoryIdentifier\":\"$GITHUB_REPOSITORY\",\"monorepo\":false}"
    
    echo "Created and bound SonarQube project: $PROJECT_KEY"
```

## With Error Checking

If you want minimal error checking:

```yaml
- name: Add Repository to SonarQube
  env:
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_ALM_KEY: ${{ secrets.SONAR_ALM_KEY }}
  run: |
    # Get DevOps platform setting ID from ALM key
    DOP_SETTINGS=$(curl -s -u "$SONAR_TOKEN:" "${SONAR_HOST_URL}/api/v2/dop-translation/dop-settings")
    DOP_SETTING_ID=$(echo "$DOP_SETTINGS" | grep -o "\"id\":\"[^\"]*\",\"type\":\"github\",\"key\":\"$SONAR_ALM_KEY\"" | grep -o "\"id\":\"[^\"]*\"" | cut -d '"' -f 4)
    
    if [ -z "$DOP_SETTING_ID" ]; then
      echo "Error: No GitHub integration found with key $SONAR_ALM_KEY"
      exit 1
    fi
    
    # Replace spaces in project name with underscores
    REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 2)
    REPO_OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d '/' -f 1)
    PROJECT_KEY="${REPO_OWNER}_${REPO_NAME}"
    
    # Check if repository is already bound to a project
    REPOS_RESPONSE=$(curl -s -u "$SONAR_TOKEN:" "${SONAR_HOST_URL}/api/alm_integrations/list_github_repositories?almSetting=$SONAR_ALM_KEY&organization=$REPO_OWNER")
    EXISTING_PROJECT=$(echo "$REPOS_RESPONSE" | grep -o "\"key\":\"$GITHUB_REPOSITORY\".*\"sqProjectKey\":\"[^\"]*\"" | grep -o "\"sqProjectKey\":\"[^\"]*\"" | cut -d '"' -f 4 || echo "")
    
    if [ ! -z "$EXISTING_PROJECT" ]; then
      echo "Repository already bound to SonarQube project: $EXISTING_PROJECT"
      exit 0
    fi
    
    # Create project and bind to GitHub repository
    CREATE_RESPONSE=$(curl -s -X POST -u "$SONAR_TOKEN:" \
      -H "Content-Type: application/json" \
      "${SONAR_HOST_URL}/api/v2/dop-translation/bound-projects" \
      -d "{\"projectKey\":\"$PROJECT_KEY\",\"projectName\":\"$REPO_NAME\",\"devOpsPlatformSettingId\":\"$DOP_SETTING_ID\",\"repositoryIdentifier\":\"$GITHUB_REPOSITORY\",\"monorepo\":false}")
    
    echo "Created and bound SonarQube project: $PROJECT_KEY"
```

## GitHub Actions Secrets Required

Add these secrets to your GitHub repository:

- `SONAR_HOST_URL`: Your SonarQube server URL (e.g., `https://sonarqube.example.com`)
- `SONAR_TOKEN`: Authentication token for SonarQube
- `SONAR_ALM_KEY`: ALM Setting key for GitHub integration in SonarQube

## Custom Project Key and Name (Optional)

If you want to customize the project key and name:

```yaml
- name: Add Repository to SonarQube with Custom Key/Name
  env:
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_ALM_KEY: ${{ secrets.SONAR_ALM_KEY }}
    CUSTOM_PROJECT_KEY: "my-custom-project-key"    # Set your custom project key
    CUSTOM_PROJECT_NAME: "My Custom Project Name"  # Set your custom project name
  run: |
    # Get DevOps platform setting ID from ALM key
    DOP_SETTING_ID=$(curl -s -u "$SONAR_TOKEN:" \
      "${SONAR_HOST_URL}/api/v2/dop-translation/dop-settings" | \
      grep -o "\"id\":\"[^\"]*\",\"type\":\"github\",\"key\":\"$SONAR_ALM_KEY\"" | \
      grep -o "\"id\":\"[^\"]*\"" | cut -d '"' -f 4)
    
    # Create project and bind to GitHub repository  
    curl -X POST -u "$SONAR_TOKEN:" \
      -H "Content-Type: application/json" \
      "${SONAR_HOST_URL}/api/v2/dop-translation/bound-projects" \
      -d "{\"projectKey\":\"$CUSTOM_PROJECT_KEY\",\"projectName\":\"$CUSTOM_PROJECT_NAME\",\"devOpsPlatformSettingId\":\"$DOP_SETTING_ID\",\"repositoryIdentifier\":\"$GITHUB_REPOSITORY\",\"monorepo\":false}"
    
    echo "Created and bound SonarQube project: $CUSTOM_PROJECT_KEY"
```
