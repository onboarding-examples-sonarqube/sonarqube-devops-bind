#!/bin/bash
# Script to batch import multiple GitHub repositories into SonarQube Server

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
    echo "  --github-org=ORG            GitHub organization name"
    echo "  --prefix=PREFIX             Prefix for SonarQube project keys (default: org name)"
    echo "  --repos-file=FILE           File containing list of repositories to import (optional)"
    echo "  --main-branch=BRANCH        Main branch name (default: main)"
    echo "  --monorepo=BOOL             Whether repositories are monorepos (default: false)"
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
        --github-org=*)
            GITHUB_ORG="${arg#*=}"
            ;;
        --prefix=*)
            PREFIX="${arg#*=}"
            ;;
        --repos-file=*)
            REPOS_FILE="${arg#*=}"
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
PREFIX=${PREFIX:-$GITHUB_ORG}

# Validate required parameters
if [[ -z $SONARQUBE_URL || -z $SONARQUBE_TOKEN || -z $ALM_SETTING || -z $GITHUB_ORG ]]; then
    log_message "ERROR" "Missing required parameters"
    show_usage
fi

# Fetch available GitHub repositories from SonarQube
log_message "INFO" "Fetching available GitHub repositories from SonarQube for organization: $GITHUB_ORG using ALM setting: $ALM_SETTING"

# API call to fetch available repositories
repos_response=$(sonarqube_api_call "GET" "/api/alm_integrations/list_github_repositories?almSetting=$ALM_SETTING&organization=$GITHUB_ORG" "$SONARQUBE_TOKEN" "$SONARQUBE_URL")

# Check if API call was successful
if echo "$repos_response" | grep -q "error"; then
    log_message "ERROR" "Failed to fetch GitHub repositories: $(echo "$repos_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
    exit 1
fi

# Parse repositories from response
repos_count=$(echo "$repos_response" | jq -r '.paging.total')
if [[ $repos_count -eq 0 ]]; then
    log_message "ERROR" "No GitHub repositories found for organization: $GITHUB_ORG with ALM setting: $ALM_SETTING"
    exit 1
fi

log_message "INFO" "Found $repos_count repositories in GitHub organization: $GITHUB_ORG"

# Get all repositories
repositories=$(echo "$repos_response" | jq -c '.repositories[]')

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

# If repos file is provided, read the repositories to import
if [[ -n $REPOS_FILE ]]; then
    if [[ ! -f $REPOS_FILE ]]; then
        log_message "ERROR" "Repos file not found: $REPOS_FILE"
        exit 1
    fi
    
    log_message "INFO" "Reading repositories from file: $REPOS_FILE"
    mapfile -t REPOS_TO_IMPORT < "$REPOS_FILE"
    
    # Trim whitespace from repo names
    for i in "${!REPOS_TO_IMPORT[@]}"; do
        REPOS_TO_IMPORT[$i]=$(echo "${REPOS_TO_IMPORT[$i]}" | xargs)
    done
    
    log_message "INFO" "Found ${#REPOS_TO_IMPORT[@]} repositories in file"
fi

# Initialize counters
success_count=0
skipped_count=0
failed_count=0

# Process each repository
while IFS= read -r repo_json; do
    # Extract repository details
    repo_key=$(echo "$repo_json" | jq -r '.key')
    repo_name=$(echo "$repo_json" | jq -r '.name')
    repo_url=$(echo "$repo_json" | jq -r '.url')
    repo_sq_project_key=$(echo "$repo_json" | jq -r '.sqProjectKey // empty')
    
    # If repos file is provided, check if this repo should be imported
    if [[ -n $REPOS_FILE ]]; then
        if [[ ! " ${REPOS_TO_IMPORT[*]} " =~ " ${repo_name} " ]]; then
            log_message "INFO" "Skipping repository $repo_name as it's not in the repos file"
            continue
        fi
    fi
    
    log_message "INFO" "Processing repository: $repo_name ($repo_key)"
    
    # Check if repository is already bound to a SonarQube project
    if [[ -n $repo_sq_project_key ]]; then
        log_message "WARNING" "Repository $repo_name is already bound to SonarQube project: $repo_sq_project_key"
        skipped_count=$((skipped_count + 1))
        continue
    fi
    
    # Generate SonarQube project key and name
    project_key="${PREFIX}_${repo_name}"
    project_name="${repo_name}"
    
    log_message "INFO" "Creating SonarQube project: $project_name ($project_key) and binding to GitHub repository: $repo_key"
    
    # API call to create project and bind to GitHub repository
    create_binding_response=$(sonarqube_api_call "POST" "/api/v2/dop-translation/bound-projects" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"projectKey\":\"$project_key\",\"projectName\":\"$project_name\",\"devOpsPlatformSettingId\":\"$dop_setting_id\",\"repositoryIdentifier\":\"$repo_key\",\"monorepo\":$MONOREPO}")
    
    if echo "$create_binding_response" | grep -q "error"; then
        log_message "ERROR" "Failed to create project and binding for $repo_name: $(echo "$create_binding_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
        failed_count=$((failed_count + 1))
        continue
    fi
    
    log_message "SUCCESS" "Successfully created project $project_key and bound to GitHub repository: $repo_key"
    
    # Update main branch name if needed
    if [[ "$MAIN_BRANCH" != "master" ]]; then
        log_message "INFO" "Setting main branch name to: $MAIN_BRANCH"
        
        branch_response=$(sonarqube_api_call "POST" "/api/project_branches/rename" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
            "{\"project\":\"$project_key\",\"name\":\"$MAIN_BRANCH\"}")
        
        if echo "$branch_response" | grep -q "error"; then
            log_message "WARNING" "Failed to rename main branch for $project_key: $(echo "$branch_response" | jq -r '.errors[0].msg // .error.message // "Unknown error"')"
        else
            log_message "INFO" "Main branch renamed to $MAIN_BRANCH"
        fi
    fi
    
    success_count=$((success_count + 1))
done <<< "$repositories"

# Print summary
log_message "INFO" "Import Summary:"
log_message "INFO" "Total repositories processed: $((success_count + skipped_count + failed_count))"
log_message "INFO" "Successfully imported: $success_count"
log_message "INFO" "Already bound (skipped): $skipped_count"
log_message "INFO" "Failed to import: $failed_count"

if [[ $failed_count -eq 0 ]]; then
    log_message "SUCCESS" "All repositories were successfully processed"
else
    log_message "WARNING" "Some repositories failed to import. Check the log for details."
fi

# Print next steps
echo ""
echo "Next Steps:"
echo "1. Add SonarQube analysis to your GitHub repository CI workflows"
echo "2. Configure GitHub pull request decoration in your repository settings"
echo "3. Run your first analysis to see results in SonarQube"
