#!/bin/bash
# Shared utility functions for installation scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced logging
log() {
  printf "${GREEN}[%s]${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

log_warn() {
  printf "${YELLOW}[%s] WARN:${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

log_error() {
  printf "${RED}[%s] ERROR:${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >&2
}

log_info() {
  printf "${BLUE}[%s] INFO:${NC} %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

# Error handling
error_exit() {
  log_error "$1"
  exit 1
}

# Check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    error_exit "This script should not be run as root. Use sudo when necessary."
  fi
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Get the script's directory
get_script_dir() {
  local script_path="${BASH_SOURCE[1]}"
  cd "$(dirname "$script_path")" && pwd
}

# Get the project root (.bspwn directory)
get_project_root() {
  local install_dir
  install_dir="$(get_script_dir)"
  dirname "$install_dir"
}

# Create backup of existing file/directory
backup_if_exists() {
  local target="$1"
  local backup_dir="${2:-$HOME/.dotfiles_backup_$(date +'%Y%m%d%H%M%S')}"
  
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$backup_dir"
    local basename
    basename=$(basename "$target")
    mv "$target" "$backup_dir/$basename"
    log "Backed up: $target -> $backup_dir/$basename"
  fi
}

# Create symlink safely
safe_symlink() {
  local source="$1"
  local target="$2"
  
  if [[ ! -e "$source" ]]; then
    log_warn "Source does not exist: $source"
    return 1
  fi
  
  # Remove existing symlink or backup existing file
  if [[ -L "$target" ]]; then
    rm -f "$target"
  elif [[ -e "$target" ]]; then
    backup_if_exists "$target"
  fi
  
  # Create parent directory if needed
  mkdir -p "$(dirname "$target")"
  
  ln -sfv "$source" "$target"
}

# Download file with progress
download_file() {
  local url="$1"
  local output="$2"
  
  if command_exists wget; then
    wget -q --show-progress "$url" -O "$output"
  elif command_exists curl; then
    curl -L --progress-bar "$url" -o "$output"
  else
    error_exit "Neither wget nor curl found. Please install one."
  fi
}

# Extract archive
extract_archive() {
  local archive="$1"
  local dest="$2"
  
  case "$archive" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$dest"
      ;;
    *.tar.xz)
      tar -xJf "$archive" -C "$dest"
      ;;
    *.zip)
      unzip -q "$archive" -d "$dest"
      ;;
    *)
      error_exit "Unknown archive format: $archive"
      ;;
  esac
}

# Confirm action
confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-n}"
  
  local yn
  if [[ "$default" == "y" ]]; then
    read -rp "$prompt [Y/n] " yn
    yn=${yn:-y}
  else
    read -rp "$prompt [y/N] " yn
    yn=${yn:-n}
  fi
  
  case "$yn" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}
