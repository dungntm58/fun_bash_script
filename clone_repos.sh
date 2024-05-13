#!/bin/bash

# Exit script on any error
set -e

repo_file="repos.txt"

# Function to read repo information from a line
read_repo_info() {
  local line="$1"
  # Skip empty lines and comment lines
  if [[ -z "$line" || $line =~ ^# ]]; then
    return 1  # Exit the function if empty or comment line
  fi
  # Separate repo name and branch name using IFS (Internal Field Separator)
  IFS=':' read -r repo_name branch_name <<< "$line"
}

# Read the URL pattern from the first line
IFS= read -r url_pattern < "$repo_file"

# Skip the first line (if not a comment) using head
if ! head -n 1 "$repo_file" | grep -q "^#"; then
  head -n 1 /dev/null < "$repo_file"  > /dev/null 2>&1
fi

# Loop through each line (skipping empty/comment lines and potentially the first line)
while IFS= read -r line; do
  if [[ $line == $url_pattern ]]; then
    continue
  fi

  # Call read_repo_info only for valid lines
  # Read repo name and branch name from the line
  if ! read_repo_info "$line"; then
    continue  # Skip to the next line if empty or comment line
  fi

  # Construct the clone URL using the pattern and repo name
  url="${url_pattern}/${repo_name}.git"

  # Check if directory exists (replace 'path/to/repos' with your desired location)
  if [ ! -d "$repo_name" ]; then
    echo "Cloning $repo_name..."
    if git ls-remote --heads origin "$branch_name" >/dev/null 2>&1; then
      git clone -b $branch_name $url $repo_name
    else
      echo "Branch $branch_name does not exist on remote for $repo_name."
    fi
  else
    echo "$repo_name already exists. Checking for branch..."
    
    cd $repo_name
    # Check if the branch already exists locally
    if git ls-remote --heads origin "$branch_name" >/dev/null 2>&1; then
      # Checkout the existing branch
      echo "Branch $branch_name already exists locally. Switching..."
      git checkout $branch_name
      git pull
    else
      echo "Branch $branch_name does not exist on remote for $repo_name."
    fi
    cd ..
  fi
done < "$repo_file"  # Notice redirection after reading the first line

echo "All repos fetched with specified branches!"
