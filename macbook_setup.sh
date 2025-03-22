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
    if [[ $(uname -m) == "arm64" ]]; then
      # For Apple Silicon Macs
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_message "$GREEN" "Homebrew installed successfully."
  fi

  # Update Homebrew
  print_message "$BLUE" "Updating Homebrew..."
  brew update || handle_error "Failed to update Homebrew"
}

# Function to install Python
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
    echo 'eval "$(rbenv init -)"' >> "$HOME/.zprofile"
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
    echo 'export GOPATH=$HOME/go' >> "$HOME/.zprofile"
    echo 'export PATH=$PATH:$GOPATH/bin' >> "$HOME/.zprofile"
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
}

# Function to set up SSH key for GitHub
setup_ssh_key() {
  print_message "$BLUE" "Checking for existing SSH key..."

  # Check if SSH key already exists
  if [ -f "$HOME/.ssh/id_ed25519" ]; then
    print_message "$GREEN" "SSH key already exists."
  else
    print_message "$YELLOW" "Generating new SSH key..."

    # Ask for email
    read -p "Enter your GitHub email address: " github_email

    # Generate SSH key
    ssh-keygen -t ed25519 -C "$github_email" -f "$HOME/.ssh/id_ed25519" -N "" || handle_error "Failed to generate SSH key"

    # Start ssh-agent and add key
    eval "$(ssh-agent -s)"
    ssh-add "$HOME/.ssh/id_ed25519" || handle_error "Failed to add SSH key to agent"

    print_message "$GREEN" "SSH key generated successfully."
  fi

  # Copy SSH key to clipboard
  pbcopy < "$HOME/.ssh/id_ed25519.pub"
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

# Main function
main() {
  print_message "$BLUE" "Starting MacBook setup..."

  # Install and configure all tools
  install_homebrew
  install_oh_my_zsh
  setup_bash_profile
  install_python
  install_ruby
  install_go
  install_node
  install_better_display
  install_copilot_for_xcode
  setup_ssh_key

  print_message "$GREEN" "MacBook setup completed successfully!"
  print_message "$YELLOW" "Note: Some changes may require a terminal restart to take effect."
}

# Run the main function
main