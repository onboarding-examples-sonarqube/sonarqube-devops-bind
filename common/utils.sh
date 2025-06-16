#!/bin/bash
# Common utility functions for SonarQube DevOps binding scripts

# Function to check if required commands are available
check_requirements() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is required but not installed. Please install it before proceeding."
            exit 1
        fi
    done
}

# Function to validate URL format
validate_url() {
    local url=$1
    if [[ ! $url =~ ^https?:// ]]; then
        echo "Error: Invalid URL format. URLs must start with http:// or https://"
        exit 1
    fi
}

# Function to make authenticated SonarQube API calls
sonarqube_api_call() {
    local method=$1
    local endpoint=$2
    local token=$3
    local base_url=$4
    local data=${5:-""}
    
    # Validate inputs
    if [[ -z $method || -z $endpoint || -z $token || -z $base_url ]]; then
        echo "Error: Missing required parameters for API call"
        return 1
    fi
    
    # Remove trailing slash from base_url if present
    base_url=${base_url%/}
    
    # Add leading slash to endpoint if not present
    [[ $endpoint != /* ]] && endpoint="/$endpoint"
    
    local url="${base_url}${endpoint}"
    
    if [[ -z $data ]]; then
        curl -s -X "$method" -H "Content-Type: application/json" -u "$token:" "$url"
    else
        curl -s -X "$method" -H "Content-Type: application/json" -u "$token:" "$url" -d "$data"
    fi
}

# Function to check if a SonarQube project exists
project_exists() {
    local project_key=$1
    local token=$2
    local base_url=$3
    
    local response=$(sonarqube_api_call "GET" "/api/projects/search?projects=$project_key" "$token" "$base_url")
    
    if echo "$response" | grep -q "\"$project_key\""; then
        return 0  # Project exists
    else
        return 1  # Project doesn't exist
    fi
}

# Function to handle errors in API responses
handle_api_response() {
    local response=$1
    local success_message=$2
    local error_message=${3:-"Operation failed"}
    
    if echo "$response" | grep -q "error"; then
        echo "$error_message: $(echo "$response" | grep -o '"message":"[^"]*"' | cut -d ':' -f 2- | tr -d '"')"
        return 1
    else
        echo "$success_message"
        return 0
    fi
}

# Function to log messages with timestamp
log_message() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Function to encode URL parameters
url_encode() {
    local string=$1
    echo "$string" | sed 's/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/\&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/-/%2D/g; s/\./%2E/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s//%3C/g; s/=/%3D/g; s/>/%3E/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\\/%5C/g; s/\]/%5D/g; s/\^/%5E/g; s/_/%5F/g; s/`/%60/g; s/{/%7B/g; s/|/%7C/g; s/}/%7D/g; s/~/%7E/g'
}
