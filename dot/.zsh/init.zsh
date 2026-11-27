# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# bspwn zsh entry point: ~/.zshrc sources this file, everything else lives in ~/.zsh/.
#
# Load order (it matters, do not sort it alphabetically):
#   config/     shell options, history, completion (zsh-autocomplete disabled, Tab-only menu), keybindings, display fix
#   prompt/     prompt, IP detection (get_ipaddr), cursor style
#   plugins/    fzf, autosuggestions (disabled, kept for reference), syntax highlighting
#   aliases/    aliases
#   functions/  helper functions (setg/unsetg pentest variables, apt wrappers, ...)
#   pentest/    optional lab helpers; a failure here never stops the shell
#   exports.zsh PATH and environment      theme.zsh  ls/less colours
#   ~/.zshrc.local  machine-specific extras, not in git (optional)
# Each *.zsh file in a directory is sourced in alphabetical order; a missing directory is ignored.

_bspwn_zsh=${HOME}/.zsh

for _bspwn_dir in config prompt plugins aliases functions; do
    for _bspwn_file in ${_bspwn_zsh}/${_bspwn_dir}/*.zsh(N); do
        source "$_bspwn_file"
    done
done

for _bspwn_file in ${_bspwn_zsh}/pentest/*.zsh(N); do
    source "$_bspwn_file" || :
done

source ${_bspwn_zsh}/exports.zsh
source ${_bspwn_zsh}/theme.zsh
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

unset _bspwn_zsh _bspwn_dir _bspwn_file
