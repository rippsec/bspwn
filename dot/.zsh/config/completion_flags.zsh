# Flag completion for tools that ship no zsh completion.
#
# zsh only completes flags for a command if a completion function exists for it;
# otherwise it falls back to file names (what you saw with `sudo arp-scan`).
# `_gnu_generic` builds one on the fly by parsing the tool's `--help` output
# (cached by zsh, so only the first Tab per command is slow).
#
# To add a tool: put its name in ~/.zsh/completions/flags.list (one per line or
# space separated, # comments allowed). Tools that already have a real
# completion are skipped, so this never overrides a better one.
#
# zsh-autocomplete runs compinit lazily, so registration happens once, at the
# first prompt, when compdef and the completion table are ready.
_flags_register() {
    local list=${ZDOTDIR:-$HOME}/.zsh/completions/flags.list line t
    if [[ -r $list ]]; then
        for line in ${(f)"$(<$list)"}; do
            line=${line%%\#*}
            for t in ${=line}; do
                (( $+commands[$t] )) && [[ -z ${_comps[$t]} ]] && compdef _gnu_generic $t
            done
        done
    fi
    add-zsh-hook -d precmd _flags_register
    unfunction _flags_register
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _flags_register
