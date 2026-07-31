#!/bin/bash

# Define the root directory where the script is stored
ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Use environment variables if set
USER_EMAIL="${USER_EMAIL:-}"
REPO_URL="${REPO_URL:-}"

if [ -z "$USER_EMAIL" ]; then
    USER_EMAIL=$(git config --global user.email)    
fi

# Check if a repository link was provided
if [[ -z "$1" && -z "$REPO_URL" ]]; then
    echo "Usage: $0 <repository-url>"
    exit 1
fi

if [[ -n "$1" ]]; then
    REPO_URL="$1"
fi

# Extract the repository name from the URL (default name of the repo)
REPO_NAME=$(basename -s .git "$REPO_URL")

# Initialization of the CLONE_PATH variable
CLONE_PATH=""

# Function to select a directory
select_directory() {
    local CURRENT_PATH="$1"

    # List child directories of the current path, excluding hidden directories
    local DIRECTORIES=()
    mapfile -t DIRECTORIES < <(find "$CURRENT_PATH" -maxdepth 1 -type d -not -path "$CURRENT_PATH" -not -name '.*' | sort)

    # Check if there are any subdirectories
    if [ ${#DIRECTORIES[@]} -eq 0 ]; then
        echo "No subdirectories available, staying in the current directory."
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
                # Recursively call select_directory for deeper navigation
                select_directory "$DIR"
                return
            fi
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Start directory selection from the root path
select_directory "$ROOT_PATH"

# Trim any trailing slashes from CLONE_PATH
CLONE_PATH="${CLONE_PATH%/}"

echo "Selected path: $CLONE_PATH"

# Create the selected path if it doesn't exist
mkdir -p "$CLONE_PATH"

# Define the full path where the repository will be cloned
TARGET_PATH="$CLONE_PATH/$REPO_NAME"

echo "Cloning repository to $TARGET_PATH"
echo "Cloning repository from $REPO_URL"

# Clone the repository using the default branch first
git clone "$REPO_URL" "$TARGET_PATH"
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