#!/bin/bash
# Neovim installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Neovim version to install
NVIM_VERSION="${NVIM_VERSION:-v0.11.0}"

install_neovim() {
  local nvim_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
  local temp_dir
  temp_dir=$(mktemp -d)

  log "Installing Neovim ${NVIM_VERSION}..."
  
  # Remove existing apt neovim if present
  if dpkg -l neovim &>/dev/null; then
    log "Removing apt-installed Neovim..."
    sudo apt remove --purge -y neovim* || true
  fi

  log "Downloading Neovim..."
  download_file "$nvim_url" "$temp_dir/nvim.tar.gz" || error_exit "Failed to download Neovim"
  
  log "Extracting Neovim..."
  extract_archive "$temp_dir/nvim.tar.gz" "$temp_dir" || error_exit "Failed to extract Neovim"

  log "Installing Neovim binary..."
  sudo install -Dm755 "$temp_dir/nvim-linux-x86_64/bin/nvim" "/usr/local/bin/nvim"
  
  log "Installing Neovim runtime files..."
  sudo cp -rv "$temp_dir/nvim-linux-x86_64/share/man/man1/nvim.1" "/usr/local/share/man/man1/" 2>/dev/null || true
  sudo cp -rv "$temp_dir/nvim-linux-x86_64/lib/nvim" "/usr/local/lib/" 2>/dev/null || true
  sudo cp -rv "$temp_dir/nvim-linux-x86_64/share/nvim" "/usr/local/share/" 2>/dev/null || true

  log "Cleaning up..."
  rm -rf "$temp_dir"

  log "Neovim ${NVIM_VERSION} installed successfully!"
  log_info "Run 'nvim' to complete LazyVim plugin installation"
}

setup_lazyvim() {
  log "Setting up LazyVim configuration..."
  
  # The nvim config should already be linked by configs.sh
  # This function just ensures the cache dirs are clean for a fresh install
  
  if confirm "Clear Neovim cache for fresh plugin install?"; then
    rm -rf "$HOME/.local/state/nvim" 2>/dev/null || true
    rm -rf "$HOME/.local/share/nvim" 2>/dev/null || true
    log "Neovim cache cleared"
  fi
  
  log_info "LazyVim configuration is ready"
  log_info "Start nvim to install plugins automatically"
}

install_nvim_dependencies() {
  log "Installing Neovim dependencies..."
  
  local deps=(
    "git"
    "ripgrep"
    "fd-find"
    "nodejs"
    "npm"
    "python3-pip"
    "python3-venv"
  )
  
  sudo apt install -y "${deps[@]}" || log_warn "Some dependencies may have failed"
  
  # Install tree-sitter CLI if not present
  if ! command_exists tree-sitter; then
    log "Installing tree-sitter CLI via npm..."
    sudo npm install -g tree-sitter-cli || log_warn "Failed to install tree-sitter"
  fi
  
  log "Neovim dependencies installed"
}

# Main installation function
install_nvim_full() {
  install_nvim_dependencies
  install_neovim
  setup_lazyvim
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_nvim_full
fi
