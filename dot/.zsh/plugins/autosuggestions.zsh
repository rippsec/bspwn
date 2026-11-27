# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# zsh-autosuggestions. (zsh-autocomplete, disabled too, is in config/completion.zsh,
# when enabled it has to come before compinit/compdef; syntax highlighting is plugins/syntax-highlighting.zsh.)
# Auto suggestions (grey history hint after the cursor): DISABLED. The settings below are kept
# for reference but never run. To use them again, delete the `return` line.
return 0
# Async so a slow lookup never blocks typing.
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_USE_ASYNC=1
    ZSH_AUTOSUGGEST_MANUAL_REBIND=1          # don't re-wrap widgets before every prompt
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60       # don't suggest for huge pasted lines
    ZSH_AUTOSUGGEST_STRATEGY=(history)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
