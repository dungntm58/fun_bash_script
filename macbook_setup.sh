#!/bin/bash

# MacBook Setup Script
# This script installs and configures development tools on a new MacBook

# Exit on any error
set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color
WORKSPACE_DIR="workspace"

# Function to print colored messages
print_message() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Function to handle errors
handle_error() {
  print_message "$RED" "Error: $1"
  exit 1
}

# Function to install Homebrew
install_homebrew() {
  print_message "$BLUE" "Checking for Homebrew..."
  if command_exists brew; then
    print_message "$GREEN" "Homebrew is already installed."
  else
    print_message "$YELLOW" "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || handle_error "Failed to install Homebrew"

    # Add Homebrew to PATH if needed
    # For Apple Silicon Macs
    eval "$(/opt/homebrew/bin/brew shellenv)"

    print_message "$GREEN" "Homebrew installed successfully."
  fi

  # Update Homebrew
  print_message "$BLUE" "Updating Homebrew..."
  brew update || handle_error "Failed to update Homebrew"
}

# Function to setup Finder sidebar
setup_finder_sidebar() {
  # Install mysides for Finder sidebar management
  if command_exists mysides; then
    print_message "$GREEN" "mysides is already installed."
  else
    print_message "$BLUE" "Installing mysides..."
    brew install mysides || handle_error "Failed to install mysides"
  fi

  print_message "$BLUE" "Setting up Finder sidebar..."

  # Create workspace directory if it doesn't exist
  mkdir -p "$HOME/$WORKSPACE_DIR"

  # Add workspace and home to Finder sidebar
  mysides add workspace "file://$HOME/$WORKSPACE_DIR"
  mysides add $(whoami) "file://$HOME"

  print_message "$GREEN" "Finder sidebar configured successfully."
}

# Function to install Python and set up a shared virtual environment
install_python() {
  print_message "$BLUE" "Checking for Python 3..."
  if command_exists python3; then
    python_version=$(python3 --version)
    print_message "$GREEN" "Python is already installed: $python_version"
  else
    print_message "$YELLOW" "Installing Python 3..."
    brew install python || handle_error "Failed to install Python"
    print_message "$GREEN" "Python 3 installed successfully: $(python3 --version)"
  fi

  # Install pipx for isolated application installation
  print_message "$BLUE" "Checking for pipx..."
  if command_exists pipx; then
    print_message "$GREEN" "pipx is already installed."
  else
    print_message "$YELLOW" "Installing pipx for Python application management..."
    brew install pipx || handle_error "Failed to install pipx"
    pipx ensurepath || handle_error "Failed to add pipx to PATH"
    print_message "$GREEN" "pipx installed successfully."
  fi

  # Set up a shared virtual environment
  print_message "$BLUE" "Setting up shared Python virtual environment..."

  # Create a central directory for the shared virtual environment
  local venv_dir="$HOME/.venvs/shared_env"

  if [ -d "$venv_dir" ]; then
    print_message "$GREEN" "Shared virtual environment already exists at $venv_dir"
  else
    print_message "$YELLOW" "Creating shared virtual environment at $venv_dir..."

    # Create the virtual environment using python3 -m venv instead of virtualenv
    mkdir -p "$HOME/.venvs"
    python3 -m venv "$venv_dir" || handle_error "Failed to create virtual environment"

    # Install basic packages in the virtual environment
    print_message "$YELLOW" "Installing basic packages in virtual environment..."
    source "$venv_dir/bin/activate"
    pip install --upgrade pip || handle_error "Failed to upgrade pip"
    pip install wheel setuptools || handle_error "Failed to install basic packages"
    deactivate

    print_message "$GREEN" "Shared virtual environment created successfully."
  fi

  # Add activation script to bash_profile if not already there
  if ! grep -q "alias activate_shared_env=" "$HOME/.bash_profile"; then
    print_message "$YELLOW" "Adding shared environment activation alias to .bash_profile..."
    echo "alias activate_shared_env='source $venv_dir/bin/activate'" >> "$HOME/.bash_profile"
  fi

  # Create a helper script to link the shared environment to projects
  local link_script="$HOME/bin/link_shared_env.sh"

  if [ ! -f "$link_script" ]; then
    print_message "$YELLOW" "Creating helper script to link shared environment to projects..."

    mkdir -p "$HOME/bin"

    cat << 'EOF' > "$link_script"
#!/bin/bash

# Script to link the shared Python environment to a project
# Usage: link_shared_env.sh [project_directory]

SHARED_ENV_DIR="$HOME/.venvs/shared_env"
PROJECT_DIR="${1:-.}"  # Use current directory if none specified

if [ ! -d "$SHARED_ENV_DIR" ]; then
  echo "Error: Shared environment not found at $SHARED_ENV_DIR"
  exit 1
fi

# Create a symlink to the shared environment
ln -sf "$SHARED_ENV_DIR" "$PROJECT_DIR/.venv"
echo "Linked shared Python environment to $PROJECT_DIR"
echo "Use 'source .venv/bin/activate' in your project to activate it"
EOF

    chmod +x "$link_script"

    # Add the bin directory to PATH if not already there
    if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.bash_profile"; then
      echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bash_profile"
    fi

    print_message "$GREEN" "Helper script created at $link_script"
    print_message "$BLUE" "Usage: link_shared_env.sh [project_directory]"
  fi

  # Create a helper script for installing Python applications with pipx
  local pipx_script="$HOME/bin/install_py_app.sh"

  if [ ! -f "$pipx_script" ]; then
    print_message "$YELLOW" "Creating helper script for installing Python applications..."

    cat << 'EOF' > "$pipx_script"
#!/bin/bash

# Script to install Python applications using pipx
# Usage: install_py_app.sh <application_name>

if [ -z "$1" ]; then
  echo "Error: Please provide an application name"
  echo "Usage: install_py_app.sh <application_name>"
  exit 1
fi

APP_NAME="$1"

echo "Installing $APP_NAME using pipx..."
pipx install "$APP_NAME"

if [ $? -eq 0 ]; then
  echo "Successfully installed $APP_NAME"
else
  echo "Failed to install $APP_NAME"
  exit 1
fi
EOF

    chmod +x "$pipx_script"

    print_message "$GREEN" "Helper script created at $pipx_script"
    print_message "$BLUE" "Usage: install_py_app.sh <application_name>"
  fi

  print_message "$GREEN" "Python environment setup complete."
  print_message "$BLUE" "To activate shared env: activate_shared_env"
  print_message "$BLUE" "To link to a project: link_shared_env.sh [project_directory]"
  print_message "$BLUE" "To install Python apps: install_py_app.sh <app_name>"
}

# Function to install rbenv and Ruby
install_ruby() {
  print_message "$BLUE" "Checking for rbenv..."
  if command_exists rbenv; then
    print_message "$GREEN" "rbenv is already installed: $(rbenv --version)"
  else
    print_message "$YELLOW" "Installing rbenv..."
    brew install rbenv || handle_error "Failed to install rbenv"
    print_message "$GREEN" "rbenv installed successfully: $(rbenv --version)"

    # Initialize rbenv
    print_message "$BLUE" "Initializing rbenv..."
    eval "$(rbenv init -)"
  fi

  # Install latest Ruby version
  print_message "$BLUE" "Checking for Ruby..."
  if command_exists ruby && [[ $(which ruby) == *".rbenv"* ]]; then
    print_message "$GREEN" "Ruby is already installed via rbenv: $(ruby --version)"
  else
    print_message "$YELLOW" "Installing latest Ruby version..."
    latest_ruby=$(rbenv install -l | grep -v - | tail -1 | tr -d ' ')
    rbenv install "$latest_ruby" || handle_error "Failed to install Ruby"
    rbenv global "$latest_ruby" || handle_error "Failed to set global Ruby version"
    print_message "$GREEN" "Ruby $latest_ruby installed successfully: $(ruby --version)"
  fi
}

# Function to install Go
install_go() {
  print_message "$BLUE" "Checking for Go..."
  if command_exists go; then
    print_message "$GREEN" "Go is already installed: $(go version)"
  else
    print_message "$YELLOW" "Installing Go..."
    brew install go || handle_error "Failed to install Go"
    print_message "$GREEN" "Go installed successfully: $(go version)"

    # Set up Go environment variables
    mkdir -p "$HOME/go/{bin,src,pkg}"
  fi
}

# Function to install nvm and Node.js
install_node() {
  print_message "$BLUE" "Checking for nvm..."
  if [ -d "$HOME/.nvm" ]; then
    print_message "$GREEN" "nvm is already installed."
  else
    print_message "$YELLOW" "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash || handle_error "Failed to install nvm"

    # Set up nvm environment
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

    print_message "$GREEN" "nvm installed successfully."
  fi

  # Source nvm if it's not already in the environment
  if ! command_exists nvm; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  fi

  # Install latest Node.js
  print_message "$BLUE" "Checking for Node.js..."
  if command_exists node; then
    print_message "$GREEN" "Node.js is already installed: $(node --version)"
  else
    print_message "$YELLOW" "Installing latest Node.js..."
    nvm install node || handle_error "Failed to install Node.js"
    nvm use node || handle_error "Failed to use latest Node.js"
    print_message "$GREEN" "Node.js installed successfully: $(node --version)"
  fi
}

# Function to install BetterDisplay
install_better_display() {
  print_message "$BLUE" "Checking for BetterDisplay..."
  if brew list --cask | grep -q "betterdisplay"; then
    print_message "$GREEN" "BetterDisplay is already installed."
  else
    print_message "$YELLOW" "Installing BetterDisplay..."
    brew install --cask betterdisplay || handle_error "Failed to install BetterDisplay"
    print_message "$GREEN" "BetterDisplay installed successfully."
  fi
}

# Function to install Copilot for Xcode
install_copilot_for_xcode() {
  print_message "$BLUE" "Checking for Copilot for Xcode..."
  if brew list --cask | grep -q "copilot-for-xcode"; then
    print_message "$GREEN" "Copilot for Xcode is already installed."
  else
    print_message "$YELLOW" "Installing Copilot for Xcode..."
    brew install --cask copilot-for-xcode || handle_error "Failed to install Copilot for Xcode"
    print_message "$GREEN" "Copilot for Xcode installed successfully."
  fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  print_message "$BLUE" "Checking for Oh My Zsh..."
  if [ -d "$HOME/.oh-my-zsh" ]; then
    print_message "$GREEN" "Oh My Zsh is already installed."
  else
    print_message "$YELLOW" "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || handle_error "Failed to install Oh My Zsh"
    print_message "$GREEN" "Oh My Zsh installed successfully."
  fi
}

# Function to set up bash profile
setup_bash_profile() {
  print_message "$BLUE" "Setting up .bash_profile..."

  # Create .bash_profile if it doesn't exist
  if [ ! -f "$HOME/.bash_profile" ]; then
    print_message "$YELLOW" "Creating .bash_profile..."
    touch "$HOME/.bash_profile"
  fi

  # Check if the content already exists to avoid duplication
  if grep -q "alias robot='python3 -m robot'" "$HOME/.bash_profile"; then
    print_message "$GREEN" ".bash_profile already configured."
  else
    print_message "$YELLOW" "Adding configurations to .bash_profile..."

    # Add the configurations to .bash_profile
    cat << 'EOF' >> "$HOME/.bash_profile"

alias robot='python3 -m robot'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export ANDROID_HOME="${HOME}/Library/Android/sdk"
export ANDROID_SDK="${HOME}/Library/Android/sdk"
export ANDROID_SDK_ROOT="${HOME}/Library/Android/sdk"
export JAVA_HOME=$(/usr/libexec/java_home)

export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH/:$ANDROID_HOME/platform-tools
export PATH=$PATH:${HOME}/flutter/bin
export PATH="$PATH":"$HOME/.pub-cache/bin"

export PATH="/opt/homebrew/bin:$PATH"
export PATH="${HOME}/.rbenv/versions/$(head -n 1 .rbenv/version)/bin:$PATH"

export GOPATH="${HOME}/go"
export GOROOT="/usr/local/go"
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"
export PATH=$PATH:$HOME/openshift

export IS_POD_BINARY_CACHE_ENABLED=true
# export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTO_UPDATE=1
source /Users/robert/.docker/init-bash.sh || true # Added by Docker Desktop

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/robert/.lmstudio/bin"
EOF

    print_message "$GREEN" ".bash_profile configured successfully."
  fi

  source "$HOME/.bash_profile"
}

# Function to set up SSH key for GitHub
setup_ssh_key() {
  print_message "$BLUE" "Checking for SSH key setup..."

  # Ask for key name with default option
  read -p "Enter a name for your SSH key (default: id_ed25519): " key_name
  key_name=${key_name:-id_ed25519}

  # Set key paths based on name
  key_path="$HOME/.ssh/$key_name"
  key_path_pub="$key_path.pub"

  # Check if SSH key already exists
  if [ -f "$key_path" ]; then
    print_message "$GREEN" "SSH key '$key_name' already exists."
  else
    print_message "$YELLOW" "Generating new SSH key with name '$key_name'..."

    # Ask for email
    read -p "Enter your GitHub email address: " github_email

    # Generate SSH key
    ssh-keygen -t ed25519 -C "$github_email" -f "$key_path" -N "" || handle_error "Failed to generate SSH key"

    # Start ssh-agent and add key
    eval "$(ssh-agent -s)"
    ssh-add "$key_path" || handle_error "Failed to add SSH key to agent"

    print_message "$GREEN" "SSH key generated successfully."
  fi

  # Copy SSH key to clipboard
  pbcopy < "$key_path_pub"
  print_message "$YELLOW" "Your SSH public key has been copied to the clipboard."

  # Prompt user to add key to GitHub
  print_message "$BLUE" "Please add this key to your GitHub account:"
  print_message "$BLUE" "1. Go to GitHub.com and sign in"
  print_message "$BLUE" "2. Click on your profile picture > Settings > SSH and GPG keys"
  print_message "$BLUE" "3. Click 'New SSH key', paste your key, and save"

  read -p "Press Enter once you've added the key to GitHub... "

  # Verify SSH connection to GitHub
  print_message "$BLUE" "Verifying SSH connection to GitHub..."
  if ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
    print_message "$GREEN" "SSH connection to GitHub verified successfully!"
  else
    print_message "$RED" "Could not verify SSH connection to GitHub. Please check your setup."
    print_message "$YELLOW" "You can try manually with: ssh -T git@github.com"
  fi
}

# Function to install Xcode snippets
install_xcode_snippets() {
  print_message "$BLUE" "Setting up Xcode snippets..."

  # Check if Xcode is installed
  if ! [ -d "/Applications/Xcode.app" ]; then
    print_message "$YELLOW" "Xcode not found. Snippets will still be installed, but Xcode is required to use them."
  fi

  # Create Xcode snippets directory if it doesn't exist
  local snippets_dir="$HOME/Library/Developer/Xcode/UserData/CodeSnippets"
  mkdir -p "$snippets_dir"

  # Create a temporary directory for the repository
  local temp_dir=$(mktemp -d)

  print_message "$YELLOW" "Downloading Xcode snippets from GitHub..."

  # Clone the repository
  git clone https://github.com/dungntm58/Snippet-Xcode.git "$temp_dir" || handle_error "Failed to clone snippets repository"

  # Copy all .codesnippet files to the Xcode snippets directory
  local snippet_count=0
  for snippet in "$temp_dir"/*.codesnippet; do
    if [ -f "$snippet" ]; then
      cp "$snippet" "$snippets_dir/"
      snippet_count=$((snippet_count + 1))
    fi
  done

  # Clean up the temporary directory
  rm -rf "$temp_dir"

  if [ $snippet_count -gt 0 ]; then
    print_message "$GREEN" "Successfully installed $snippet_count Xcode snippets."
    print_message "$BLUE" "Snippets are available in Xcode's code completion or from the Code Snippet Library (View > Show Library)."
  else
    print_message "$YELLOW" "No snippets were found in the repository."
  fi
}

# Main function
main() {
  print_message "$BLUE" "Starting MacBook setup..."

  # Install and configure all tools
  install_homebrew
  setup_finder_sidebar
  install_oh_my_zsh
  setup_bash_profile
  install_python
  install_ruby
  install_go
  install_node
  install_better_display
  install_copilot_for_xcode
  setup_ssh_key
  install_xcode_snippets

  print_message "$GREEN" "MacBook setup completed successfully!"
  print_message "$YELLOW" "Note: Some changes may require a terminal restart to take effect."
}

# Run the main function
main