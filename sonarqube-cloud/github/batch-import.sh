#!/bin/bash
# Script to batch import multiple GitHub repositories into SonarQube Cloud

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
    echo "  --github-token=TOKEN        GitHub personal access token"
    echo "  --org=ORGANIZATION          GitHub organization name"
    echo "  --repos-file=FILE           File containing list of repositories to import"
    echo "  --prefix=PREFIX             Prefix for SonarQube project keys (default: org name)"
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
        --github-token=*)
            DEVOPS_TOKEN="${arg#*=}"
            ;;
        --org=*)
            GITHUB_ORG="${arg#*=}"
            ;;
        --repos-file=*)
            REPOS_FILE="${arg#*=}"
            ;;
        --prefix=*)
            PREFIX="${arg#*=}"
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
PREFIX=${PREFIX:-$GITHUB_ORG}

# Validate required parameters
if [[ -z $SONARQUBE_TOKEN || -z $ORGANIZATION || -z $DEVOPS_TOKEN || -z $GITHUB_ORG ]]; then
    log_message "ERROR" "Missing required parameters"
    show_usage
fi

# Check if repos file exists or retrieve from GitHub API
if [[ -z $REPOS_FILE ]]; then
    log_message "INFO" "No repos file provided, retrieving repositories from GitHub API for organization: $GITHUB_ORG"
    
    # Retrieve repositories from GitHub API
    REPOS_RESPONSE=$(curl -s -H "Authorization: token $DEVOPS_TOKEN" \
        "https://api.github.com/orgs/$GITHUB_ORG/repos?per_page=100")
    
    if echo "$REPOS_RESPONSE" | grep -q "message.*Not Found"; then
        log_message "ERROR" "GitHub organization not found: $GITHUB_ORG"
        exit 1
    fi
    
    # Extract repository names
    REPOS=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))
    
    if [[ ${#REPOS[@]} -eq 0 ]]; then
        log_message "ERROR" "No repositories found for organization: $GITHUB_ORG"
        exit 1
    fi
    
    log_message "INFO" "Found ${#REPOS[@]} repositories in organization: $GITHUB_ORG"
else
    if [[ ! -f $REPOS_FILE ]]; then
        log_message "ERROR" "Repos file not found: $REPOS_FILE"
        exit 1
    fi
    
    # Read repository names from file
    mapfile -t REPOS < "$REPOS_FILE"
    log_message "INFO" "Loaded ${#REPOS[@]} repositories from file: $REPOS_FILE"
fi

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

# Process each repository
success_count=0
failed_count=0

for repo in "${REPOS[@]}"; do
    # Skip empty lines
    if [[ -z $repo ]]; then
        continue
    fi
    
    # Trim whitespace
    repo=$(echo "$repo" | xargs)
    
    log_message "INFO" "Processing repository: $repo"
    
    # Generate SonarQube project key and name
    PROJECT_KEY="${PREFIX}_${repo}"
    PROJECT_NAME="${repo}"
    REPOSITORY_URL="https://github.com/$GITHUB_ORG/$repo"
    
    log_message "INFO" "Creating SonarQube project: $PROJECT_NAME ($PROJECT_KEY)"
    
    # Check if project already exists
    if project_exists "$PROJECT_KEY" "$SONARQUBE_TOKEN" "$SONARQUBE_URL"; then
        log_message "WARNING" "Project $PROJECT_KEY already exists in SonarQube Cloud, skipping creation"
    else
        # Create project in SonarQube Cloud
        create_response=$(sonarqube_api_call "POST" "/api/projects/create" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
            "{\"name\":\"$PROJECT_NAME\",\"project\":\"$PROJECT_KEY\",\"organization\":\"$ORGANIZATION\",\"visibility\":\"private\"}")
        
        if ! handle_api_response "$create_response" "Project created successfully" "Failed to create project"; then
            failed_count=$((failed_count + 1))
            continue
        fi
    fi
    
    log_message "INFO" "Binding project to GitHub repository: $GITHUB_ORG/$repo"
    
    # Bind the project to GitHub repository
    binding_response=$(sonarqube_api_call "POST" "/api/alm_settings/set_github_binding" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
        "{\"almSetting\":\"$github_alm_key\",\"organization\":\"$ORGANIZATION\",\"project\":\"$PROJECT_KEY\",\"repository\":\"$repo\",\"repositoryKey\":\"$GITHUB_ORG/$repo\",\"summaryCommentEnabled\":true}")
    
    if ! handle_api_response "$binding_response" "GitHub binding created successfully" "Failed to create GitHub binding"; then
        failed_count=$((failed_count + 1))
        continue
    fi
    
    # Update main branch name if needed
    if [[ "$MAIN_BRANCH" != "master" ]]; then
        log_message "INFO" "Setting main branch name to: $MAIN_BRANCH"
        
        branch_response=$(sonarqube_api_call "POST" "/api/project_branches/rename" "$SONARQUBE_TOKEN" "$SONARQUBE_URL" \
            "{\"project\":\"$PROJECT_KEY\",\"name\":\"$MAIN_BRANCH\"}")
        
        handle_api_response "$branch_response" "Main branch renamed to $MAIN_BRANCH" "Failed to rename main branch"
    fi
    
    log_message "SUCCESS" "Repository $repo successfully added to SonarQube Cloud"
    success_count=$((success_count + 1))
done

# Print summary
log_message "INFO" "Import Summary:"
log_message "INFO" "Total repositories processed: $((success_count + failed_count))"
log_message "INFO" "Successfully imported: $success_count"
log_message "INFO" "Failed to import: $failed_count"

if [[ $failed_count -eq 0 ]]; then
    log_message "SUCCESS" "All repositories were successfully imported to SonarQube Cloud"
else
    log_message "WARNING" "Some repositories failed to import. Check the log for details."
fi
