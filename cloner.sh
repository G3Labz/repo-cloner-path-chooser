#!/bin/bash

# Define the root directory where the script is stored
ROOT_PATH="$(dirname "$0")"

# Define the predefined paths for cloning repositories
PREDEFINED_PATHS=("$ROOT_PATH/repos1" "$ROOT_PATH/repos2" "$ROOT_PATH/repos3")

# Define the predefined user email
USER_EMAIL="your-email@example.com"

# Check if a repository link was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <repository-url>"
    exit 1
fi

# Get the repository URL from the argument
REPO_URL="$1"

# Extract the repository name from the URL
REPO_NAME=$(basename -s .git "$REPO_URL")

# Prompt the user to select a predefined path
echo "Please select the path to clone the repository into:"
select CLONE_PATH in "${PREDEFINED_PATHS[@]}"; do
    if [[ -n "$CLONE_PATH" ]]; then
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# Create the selected path if it doesn't exist
mkdir -p "$CLONE_PATH"

# Define the full path where the repository will be cloned
TARGET_PATH="$CLONE_PATH/$REPO_NAME"

# Clone the repository into the target path
git clone "$REPO_URL" "$TARGET_PATH"

# Check if the clone was successful
if [ $? -ne 0 ]; then
    echo "Failed to clone repository."
    exit 1
fi

# Set the local Git config user email
cd "$TARGET_PATH" || exit
git config --local user.email "$USER_EMAIL"

echo "Repository cloned to $TARGET_PATH and user.email set to $USER_EMAIL"
