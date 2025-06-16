#!/bin/bash
# Script to create a new SonarQube project and bind it to GitHub
# For SonarQube Server instances

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
    echo "  --sonarqube-url=URL         SonarQube server URL"
    echo "  --sonarqube-token=TOKEN     SonarQube authentication token"
    echo "  --alm-setting=KEY           SonarQube ALM Setting key for GitHub integration"
    echo "  --project-key=KEY           SonarQube project key"
    echo "  --project-name=NAME         SonarQube project name"
    echo "  --repo-url=URL              GitHub repository URL"
    echo "  --main-branch=BRANCH        Main branch name (default: main)"
    echo "  --monorepo=BOOL             Whether repository is a monorepo (default: false)"
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
        --alm-setting=*)
            ALM_SETTING="${arg#*=}"
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
        --main-branch=*)
            MAIN_BRANCH="${arg#*=}"
            ;;
        --monorepo=*)
            MONOREPO="${arg#*=}"
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
MAIN_BRANCH=${MAIN_BRANCH:-"main"}
MONOREPO=${MONOREPO:-"false"}

# Validate required parameters
if [[ -z $SONARQUBE_URL || -z $SONARQUBE_TOKEN || -z $ALM_SETTING || -z $PROJECT_KEY || -z $PROJECT_NAME || -z $REPOSITORY_URL ]]; then
    log_message "ERROR" "Missing required parameters"
    show_usage
fi

# Extract GitHub repository details from URL
# Example URL: https://github.com/owner/repo
REPOSITORY_OWNER=$(echo "$REPOSITORY_URL" | sed -E 's|https://github.com/([^/]+)/.*|\1|')
REPOSITORY_NAME=$(echo "$REPOSITORY_URL" | sed -E 's|https://github.com/[^/]+/([^/]+).*|\1|')
REPOSITORY_IDENTIFIER="${REPOSITORY_OWNER}/${REPOSITORY_NAME}"

log_message "INFO" "Creating SonarQube project: $PROJECT_NAME ($PROJECT_KEY)"

# Fetch DevOps platform settings to get the correct DevOps platform ID
log_message "INFO" "Fetching DevOps platform settings from SonarQube"

# API call to fetch DevOps platform settings
dop_settings_response=$(sonarqube_api_call "GET" "/api/v2/dop-translation/dop-settings" "$SONARQUBE_TOKEN" "$SONARQUBE_URL")

# Check if API call was successful
if echo "$dop_settings_response" | grep -q "error"; then
    log_message "ERROR" "Failed to fetch DevOps platform settings: $(echo "$dop_settings_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
    exit 1
fi

# Find the correct DevOps platform setting ID for the given ALM setting key
dop_setting_id=$(echo "$dop_settings_response" | jq -r ".dopSettings[] | select(.key == \"$ALM_SETTING\" and .type == \"github\") | .id")

if [[ -z $dop_setting_id || $dop_setting_id == "null" ]]; then
    log_message "ERROR" "No GitHub DevOps platform setting found with key: $ALM_SETTING"
    exit 1
fi

log_message "INFO" "Found DevOps platform setting ID: $dop_setting_id for ALM setting: $ALM_SETTING"

# Check if the repository exists in the GitHub integration
log_message "INFO" "Checking if repository $REPOSITORY_IDENTIFIER exists in GitHub integration"

# API call to fetch available repositories
repos_response=$(sonarqube_api_call "GET" "/api/alm_integrations/list_github_repositories?almSetting=$ALM_SETTING&organization=$REPOSITORY_OWNER" "$SONARQUBE_TOKEN" "$SONARQUBE_URL")

# Check if API call was successful
if echo "$repos_response" | grep -q "error"; then
    log_message "ERROR" "Failed to fetch GitHub repositories: $(echo "$repos_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
    exit 1
fi

# Check if repository exists in the response
repo_exists=$(echo "$repos_response" | jq -r ".repositories[] | select(.key == \"$REPOSITORY_IDENTIFIER\") | .key")

if [[ -z $repo_exists ]]; then
    log_message "ERROR" "Repository $REPOSITORY_IDENTIFIER not found in GitHub integration with ALM setting: $ALM_SETTING"
    exit 1
fi

# Check if repository is already bound to a SonarQube project
repo_sq_project_key=$(echo "$repos_response" | jq -r ".repositories[] | select(.key == \"$REPOSITORY_IDENTIFIER\") | .sqProjectKey // empty")

if [[ -n $repo_sq_project_key ]]; then
    log_message "WARNING" "Repository $REPOSITORY_IDENTIFIER is already bound to SonarQube project: $repo_sq_project_key"
    log_message "INFO" "You may want to use a different repository or update the existing binding"
    exit 1
fi

# Create project and bind to GitHub repository
log_message "INFO" "Creating SonarQube project and binding to GitHub repository: $REPOSITORY_IDENTIFIER"

# API call to create project and bind to GitHub repository
create_binding_response=$(sonarqube_api_call "POST" "/api/v2/dop-translation/bound-projects" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
    "{\"projectKey\":\"$PROJECT_KEY\",\"projectName\":\"$PROJECT_NAME\",\"devOpsPlatformSettingId\":\"$dop_setting_id\",\"repositoryIdentifier\":\"$REPOSITORY_IDENTIFIER\",\"monorepo\":$MONOREPO}")

# Check if API call was successful
if echo "$create_binding_response" | grep -q "error"; then
    log_message "ERROR" "Failed to create project and binding: $(echo "$create_binding_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
    exit 1
fi

log_message "SUCCESS" "Successfully created project $PROJECT_KEY and bound to GitHub repository: $REPOSITORY_IDENTIFIER"

# Update main branch name if needed
if [[ "$MAIN_BRANCH" != "master" ]]; then
    log_message "INFO" "Setting main branch name to: $MAIN_BRANCH"
    
    branch_response=$(sonarqube_api_call "POST" "/api/project_branches/rename" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"project\":\"$PROJECT_KEY\",\"name\":\"$MAIN_BRANCH\"}")
    
    if echo "$branch_response" | grep -q "error"; then
        log_message "WARNING" "Failed to rename main branch: $(echo "$branch_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
    else
        log_message "INFO" "Main branch renamed to $MAIN_BRANCH"
    fi
fi

log_message "SUCCESS" "Project successfully created and bound to GitHub repository"
log_message "INFO" "Project Key: $PROJECT_KEY"
log_message "INFO" "Repository: $REPOSITORY_IDENTIFIER"
log_message "INFO" "Main Branch: $MAIN_BRANCH"

# Print next steps
echo ""
echo "Next Steps:"
echo "1. Add SonarQube analysis to your GitHub repository CI workflow"
echo "2. Configure GitHub pull request decoration in your repository settings"
echo "3. Run your first analysis to see results in SonarQube"
