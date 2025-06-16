#!/bin/bash
# Script to create a new SonarQube Cloud project and bind it to GitHub
# For SonarQube Cloud instances

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/utils.sh"

# Source configuration if exists
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Check required tools
check_requirements "curl" "jq"

# Function to show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --sonarqube-url=URL         SonarQube Cloud URL (default: https://sonarcloud.io)"
    echo "  --sonarqube-token=TOKEN     SonarQube authentication token"
    echo "  --organization=ORG          SonarQube Cloud organization key"
    echo "  --project-key=KEY           SonarQube project key"
    echo "  --project-name=NAME         SonarQube project name"
    echo "  --repo-url=URL              GitHub repository URL"
    echo "  --github-token=TOKEN        GitHub personal access token"
    echo "  --main-branch=BRANCH        Main branch name (default: main)"
    echo "  --help                      Show this help message"
    exit 1
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --sonarqube-url=*)
            SONARQUBE_URL="${arg#*=}"
            ;;
        --sonarqube-token=*)
            SONARQUBE_TOKEN="${arg#*=}"
            ;;
        --organization=*)
            ORGANIZATION="${arg#*=}"
            ;;
        --project-key=*)
            PROJECT_KEY="${arg#*=}"
            ;;
        --project-name=*)
            PROJECT_NAME="${arg#*=}"
            ;;
        --repo-url=*)
            REPOSITORY_URL="${arg#*=}"
            ;;
        --github-token=*)
            DEVOPS_TOKEN="${arg#*=}"
            ;;
        --main-branch=*)
            MAIN_BRANCH="${arg#*=}"
            ;;
        --help)
            show_usage
            ;;
        *)
            echo "Unknown option: $arg"
            show_usage
            ;;
    esac
done

# Set default values
SONARQUBE_URL=${SONARQUBE_URL:-"https://sonarcloud.io"}
MAIN_BRANCH=${MAIN_BRANCH:-"main"}

# Validate required parameters
if [[ -z $SONARQUBE_TOKEN || -z $ORGANIZATION || -z $PROJECT_KEY || -z $PROJECT_NAME || -z $REPOSITORY_URL || -z $DEVOPS_TOKEN ]]; then
    log_message "ERROR" "Missing required parameters"
    show_usage
fi

# Extract GitHub repository details from URL
# Example URL: https://github.com/owner/repo
REPOSITORY_OWNER=$(echo "$REPOSITORY_URL" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
REPOSITORY_NAME=$(echo "$REPOSITORY_URL" | sed -E 's|https://github.com/[^/]+/([^/]+).*|\1|')

log_message "INFO" "Creating SonarQube Cloud project: $PROJECT_NAME ($PROJECT_KEY) in organization: $ORGANIZATION"

# Check if project already exists
if project_exists "$PROJECT_KEY" "$SONARQUBE_TOKEN" "$SONARQUBE_URL"; then
    log_message "WARNING" "Project $PROJECT_KEY already exists in SonarQube Cloud"
else
    # Create project in SonarQube Cloud
    create_response=$(sonarqube_api_call "POST" "/api/projects/create" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"name\":\"$PROJECT_NAME\",\"project\":\"$PROJECT_KEY\",\"organization\":\"$ORGANIZATION\",\"visibility\":\"private\"}")
    
    if ! handle_api_response "$create_response" "Project created successfully" "Failed to create project"; then
        exit 1
    fi
fi

log_message "INFO" "Binding project to GitHub repository: $REPOSITORY_OWNER/$REPOSITORY_NAME"

# Get the ALM Setting key for GitHub
alm_settings_response=$(sonarqube_api_call "GET" "/api/alm_settings/list_definitions" "$SONARQUBE_TOKEN" "$SONARQUBE_URL")
github_alm_key=$(echo "$alm_settings_response" | jq -r '.github.keys[0]')

if [[ -z $github_alm_key || $github_alm_key == "null" ]]; then
    log_message "INFO" "No GitHub ALM settings found. Creating a new one."
    
    # Create a new GitHub ALM binding for the organization
    alm_create_response=$(sonarqube_api_call "POST" "/api/alm_settings/create_github" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"organization\":\"$ORGANIZATION\",\"url\":\"https://api.github.com\",\"appId\":\"sonarcloud\",\"clientId\":\"automatic\",\"clientSecret\":\"automatic\",\"key\":\"github-$ORGANIZATION\"}")
    
    if ! handle_api_response "$alm_create_response" "GitHub ALM settings created successfully" "Failed to create GitHub ALM settings"; then
        exit 1
    fi
    
    github_alm_key="github-$ORGANIZATION"
fi

# Bind the project to GitHub repository
binding_response=$(sonarqube_api_call "POST" "/api/alm_settings/set_github_binding" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
    "{\"almSetting\":\"$github_alm_key\",\"organization\":\"$ORGANIZATION\",\"project\":\"$PROJECT_KEY\",\"repository\":\"$REPOSITORY_NAME\",\"repositoryKey\":\"$REPOSITORY_OWNER/$REPOSITORY_NAME\",\"summaryCommentEnabled\":true}")

if ! handle_api_response "$binding_response" "GitHub binding created successfully" "Failed to create GitHub binding"; then
    exit 1
fi

# Update main branch name if needed
if [[ "$MAIN_BRANCH" != "master" ]]; then
    log_message "INFO" "Setting main branch name to: $MAIN_BRANCH"
    
    branch_response=$(sonarqube_api_call "POST" "/api/project_branches/rename" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"project\":\"$PROJECT_KEY\",\"name\":\"$MAIN_BRANCH\"}")
    
    handle_api_response "$branch_response" "Main branch renamed to $MAIN_BRANCH" "Failed to rename main branch"
fi

log_message "SUCCESS" "Project successfully created and bound to GitHub repository"
log_message "INFO" "Project Key: $PROJECT_KEY"
log_message "INFO" "Organization: $ORGANIZATION"
log_message "INFO" "Repository: $REPOSITORY_OWNER/$REPOSITORY_NAME"
log_message "INFO" "Main Branch: $MAIN_BRANCH"

# Print next steps
echo ""
echo "Next Steps:"
echo "1. Add SonarCloud analysis to your GitHub repository CI workflow"
echo "2. Configure GitHub pull request decoration in your repository settings"
echo "3. Run your first analysis to see results in SonarCloud"
