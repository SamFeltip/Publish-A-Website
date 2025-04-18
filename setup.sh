#!/bin/bash

# === CHECK FOR NECESSARY TOOLS ===

check_command() {
  echo "💭 checking $1 is installed..."
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "⚠️  $1 is not installed. Let's fix that!"
    read -p "Do you want to install $1 now? (y/n) " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
      install_tool "$1" "$2"
      ensure_tool_in_path "$1"
    else
      echo "❌ Exiting. $1 is required to continue."
      exit 1
    fi
  fi
}

install_brew() {
  echo "🔧 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "🍺 Homebrew has been installed. Re-run the script to continue."
  exit 1
}

install_tool() {
  TOOL_NAME="$1"
  INSTALL_METHOD="$2"

  if [[ "$TOOL_NAME" == "brew" ]]; then
    if command -v brew >/dev/null 2>&1; then
      echo "🍺 Homebrew is already installed!"
    else
      install_brew
    fi
  elif [[ "$INSTALL_METHOD" == "brew" ]]; then
    if command -v brew >/dev/null 2>&1; then
      echo "🔧 Installing $TOOL_NAME using Homebrew..."
      brew install "$TOOL_NAME"
    else
      echo "⚠️  Homebrew is not installed. Please install Homebrew first or choose npm."
      exit 1
    fi
  elif [[ "$INSTALL_METHOD" == "npm" ]]; then
    echo "🔧 Installing $TOOL_NAME using npm..."
    npm install -g "$TOOL_NAME"
  else
    echo "❓ Invalid install method specified. Please use 'brew' or 'npm'."
    exit 1
  fi
}

ensure_tool_in_path() {
  local tool="$1"
  local bin_path
  bin_path="$(command -v "$tool" 2>/dev/null)"

  if [[ -z "$bin_path" ]]; then
    local homebrew_bin="/opt/homebrew/bin"
    local intelbrew_bin="/usr/local/bin"
    if [[ -x "$homebrew_bin/$tool" ]]; then
      add_to_path "$homebrew_bin"
    elif [[ -x "$intelbrew_bin/$tool" ]]; then
      add_to_path "$intelbrew_bin"
    else
      echo "⚠️  Couldn't find $tool in expected locations. You may need to close/open your terminal or add it manually to PATH."
      exit 1
    fi
  fi
}

add_to_path() {
  local new_path="$1"
  if [[ "$SHELL" == */zsh ]]; then
    profile_file="$HOME/.zprofile"
  else
    profile_file="$HOME/.bash_profile"
  fi

  if ! grep -q "$new_path" "$profile_file" 2>/dev/null; then
    echo "➕ Adding $new_path to PATH in $profile_file"
    echo "export PATH=\"$new_path:\$PATH\"" >> "$profile_file"
    echo "✅ Path updated. Close & reopen your terminal to finish setting up the new tool."
  else
    echo "✅ $new_path is already in your PATH"
  fi
}

intro_banner() {
  clear
  echo ""
  echo "✨ Welcome, brave site builder!"
}

intro_banner
echo "Let's conjure up an Astro site and launch it into the Cloudflare cosmos."
sleep 2
intro_banner
echo "Before we can get started, lets check you have all our dependencies installed..."
sleep 2

check_command "brew"
check_command "npm"  "brew"
check_command "git"  "brew"
check_command "gh"   "brew"
check_command "wrangler" "npm"

echo "✅ All required tools are installed!"
