#!/usr/bin/env bash

_checkpac() {
    local cur prev opts shortopts longopts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # args
    shortopts="-h -r -d -e"
    longopts="--help --remote --desc --exact --exclude-aur --exclude-arch"
    opts="$shortopts $longopts"

    # if dash, give arg completions
    if [[ ${cur} == -* ]] ; then
        # if double dash, only long opts
        if [[ ${cur} == --* ]] ; then
            COMPREPLY=( $(compgen -W "$longopts" -- "${cur}") )
        # if single dash, all opts
        else
            COMPREPLY=( $(compgen -W "$opts" -- "${cur}") )
        fi
        return 0
    fi

    # if not dash, suggest packages
    if [[ ${prev} != -* ]] ; then
        local packages
        packages=$(pacman -Qq)
        COMPREPLY=( $(compgen -W "${packages}" -- "${cur}") )
        return 0
    fi
}

complete -F _checkpac checkpac