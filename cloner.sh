#!/bin/bash

# Define the root directory where the script is stored
ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"

# Define the predefined user email
USER_EMAIL="your-email@example.com"

# Check if a repository link was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <repository-url>"
    exit 1
fi

# Get the repository URL from the argument
REPO_URL="$1"

# Extract the repository name from the URL (default name of the repo)
REPO_NAME=$(basename -s .git "$REPO_URL")

# Initialization of the CLONE_PATH variable
CLONE_PATH=""

# Function to select a directory
select_directory() {
    local CURRENT_PATH="$1"

    # List child directories of the current path, excluding hidden directories
    IFS=$'\n' DIRECTORIES=($(find "$CURRENT_PATH" -maxdepth 1 -type d -not -path "$CURRENT_PATH" -not -name '.*'))

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
                CLONE_PATH=$CURRENT_PATH
                return
            elif [[ -d "$DIR" ]]; then
                # Ask if the user wants to navigate deeper
                echo "Do you want to go deeper into $DIR? (y/n)"
                read -r answer
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    # Recursively call select_directory for deeper navigation
                    select_directory "$DIR"
                    return
                else
                    echo "Selected directory: $DIR"
                    CLONE_PATH=$DIR
                    return
                fi
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