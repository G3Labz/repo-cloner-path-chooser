#!/bin/bash

# Define the root directory where the script is stored
ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Use environment variables if set
USER_EMAIL="${USER_EMAIL:-}"
REPO_URL="${REPO_URL:-}"

if [ -z "$USER_EMAIL" ]; then
    USER_EMAIL=$(git config --global user.email)    
fi

# Prompt for repository URL if not provided via parameter or environment
if [[ -z "$1" && -z "$REPO_URL" ]]; then
    read -p "Paste the Git repository URL: " TYPED_URL
    REPO_URL="$TYPED_URL"
fi

if [[ -n "$1" ]]; then
    REPO_URL="$1"
fi

if [ -z "$REPO_URL" ]; then
    echo "Error: No repository URL provided."
    exit 1
fi

# Clean repository URL (remove query parameters like ?version=... and trailing slashes)
CLEAN_REPO_URL="${REPO_URL%%\?*}"
CLEAN_REPO_URL="${CLEAN_REPO_URL%/}"

# Extract the repository name from the URL
REPO_NAME=$(basename -s .git "$CLEAN_REPO_URL")

# Helper function to find a case-insensitive directory match in a parent path
find_matching_dir() {
    local parent="$1"
    local target="$2"
    if [ ! -d "$parent" ]; then
        echo "$target"
        return
    fi
    local match
    match=$(find "$parent" -maxdepth 1 -mindepth 1 -type d -iname "$target" -print -quit 2>/dev/null)
    if [ -n "$match" ]; then
        basename "$match"
    else
        echo "$target"
    fi
}

# Function to determine smart recommended path relative to ROOT_PATH
get_smart_recommended_path() {
    local url="$1"
    url="${url%%\?*}"
    url="${url%/}"
    url="${url%.git}"

    local rel_path=""

    # 1. Azure DevOps URLs:
    # Pattern: https://dev.azure.com/{org}/{project}/_git/{repo}
    # Pattern: git@ssh.dev.azure.com:v3/{org}/{project}/{repo}
    # Pattern: https://{org}.visualstudio.com/{project}/_git/{repo}
    if [[ "$url" =~ dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+) ]] || \
       [[ "$url" =~ dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/]+) ]]; then
        local org="${BASH_REMATCH[1]}"
        local project="${BASH_REMATCH[2]}"
        local repo="${BASH_REMATCH[3]}"

        local work_dir
        work_dir=$(find_matching_dir "$ROOT_PATH" "Work")
        local org_dir
        org_dir=$(find_matching_dir "$ROOT_PATH/$work_dir" "$org")
        local proj_dir
        proj_dir=$(find_matching_dir "$ROOT_PATH/$work_dir/$org_dir" "$project")

        rel_path="$work_dir/$org_dir/$proj_dir/$repo"

    elif [[ "$url" =~ ([^/\.]+)\.visualstudio\.com/([^/]+)/_git/([^/]+) ]]; then
        local org="${BASH_REMATCH[1]}"
        local project="${BASH_REMATCH[2]}"
        local repo="${BASH_REMATCH[3]}"

        local work_dir
        work_dir=$(find_matching_dir "$ROOT_PATH" "Work")
        local org_dir
        org_dir=$(find_matching_dir "$ROOT_PATH/$work_dir" "$org")
        local proj_dir
        proj_dir=$(find_matching_dir "$ROOT_PATH/$work_dir/$org_dir" "$project")

        rel_path="$work_dir/$org_dir/$proj_dir/$repo"

    # 2. GitHub / GitLab / Bitbucket / Generic owner/repo pattern:
    elif [[ "$url" =~ [:/]([^/]+)/([^/]+)$ ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"

        local owner_dir
        owner_dir=$(find_matching_dir "$ROOT_PATH" "$owner")

        rel_path="$owner_dir/$repo"
    fi

    echo "$rel_path"
}

# Function to select a directory manually
CLONE_PATH=""
select_directory() {
    local CURRENT_PATH="$1"

    # List child directories of the current path, excluding hidden directories
    local DIRECTORIES=()
    mapfile -t DIRECTORIES < <(find "$CURRENT_PATH" -maxdepth 1 -type d -not -path "$CURRENT_PATH" -not -name '.*' | sort)

    # Check if there are any subdirectories
    if [ ${#DIRECTORIES[@]} -eq 0 ]; then
        echo "No subdirectories available, staying in current directory ($CURRENT_PATH)."
        CLONE_PATH="$CURRENT_PATH"
        return
    fi

    # Display options to the user
    echo "Please select a directory or stay in the current directory ($CURRENT_PATH):"
    echo ""
    select DIR in "${DIRECTORIES[@]}" "Stay in the current directory"; do
        if [[ "$REPLY" -le $((${#DIRECTORIES[@]} + 1)) && "$REPLY" -gt 0 ]]; then
            if [[ "$DIR" == "Stay in the current directory" ]]; then
                echo "Selected current directory: $CURRENT_PATH"
                CLONE_PATH="$CURRENT_PATH"
                return
            elif [[ -d "$DIR" ]]; then
                select_directory "$DIR"
                return
            fi
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Smart Path Recommendation & Prompt
SMART_REL_PATH=$(get_smart_recommended_path "$CLEAN_REPO_URL")
TARGET_PATH=""

if [ -n "$SMART_REL_PATH" ]; then
    RECOMMENDED_TARGET="$ROOT_PATH/$SMART_REL_PATH"
    
    echo "=========================================================="
    echo "Smart Recommendation: $SMART_REL_PATH"
    echo "Full Target Path:     $RECOMMENDED_TARGET"
    echo "=========================================================="
    echo ""
    
    PS3="Select choice (1-2): "
    options=("Clone in recommended path ($SMART_REL_PATH)" "Choose directory manually")
    select opt in "${options[@]}"; do
        case $opt in
            "Clone in recommended path ("*)
                TARGET_PATH="$RECOMMENDED_TARGET"
                break
                ;;
            "Choose directory manually")
                select_directory "$ROOT_PATH"
                CLONE_PATH="${CLONE_PATH%/}"
                TARGET_PATH="$CLONE_PATH/$REPO_NAME"
                break
                ;;
            *)
                echo "Invalid selection. Please try again."
                ;;
        esac
    done
else
    select_directory "$ROOT_PATH"
    CLONE_PATH="${CLONE_PATH%/}"
    TARGET_PATH="$CLONE_PATH/$REPO_NAME"
fi

# Ensure parent directory exists
mkdir -p "$(dirname "$TARGET_PATH")"

echo "Cloning repository to $TARGET_PATH"
echo "Cloning repository from $CLEAN_REPO_URL"

# Clone the repository using the default branch first
git clone "$CLEAN_REPO_URL" "$TARGET_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to clone repository."
    exit 1
fi

# Enter target directory
cd "$TARGET_PATH" || exit 1

# Check for preferred branches in priority order (develop, dev, master, main)
PREFERRED_BRANCHES=("develop" "dev" "master" "main")
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

for branch in "${PREFERRED_BRANCHES[@]}"; do
    if [ "$CURRENT_BRANCH" = "$branch" ]; then
        echo "Already on preferred branch '$branch'."
        break
    fi
    if git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        echo "Found branch '$branch' on remote. Switching to '$branch'..."
        git checkout "$branch"
        break
    fi
done

USER_DEFAULT_NAME=$(git config --global user.name)

# Set the local Git config user email and name
if [ -n "$USER_EMAIL" ]; then
    git config --local user.email "$USER_EMAIL"
fi
if [ -n "$USER_DEFAULT_NAME" ]; then
    git config --local user.name "$USER_DEFAULT_NAME"
fi

ACTIVE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Repository successfully cloned to $TARGET_PATH (Active branch: $ACTIVE_BRANCH)."
echo "Local Git configuration updated: user.email='$USER_EMAIL', user.name='$USER_DEFAULT_NAME'."