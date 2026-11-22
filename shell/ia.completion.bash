# Autocompletar do `ia` para o bash (carregado sob demanda pelo bash-completion).

_ia() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Primeira palavra (ou depois de -p): atalhos e opções.
    if [ "$COMP_CWORD" -eq 1 ] || { [ "$COMP_CWORD" -eq 2 ] && [[ "$prev" == -p || "$prev" == --pensar ]]; }; then
        local atalhos
        atalhos=$(ia --lista-atalhos 2>/dev/null)
        COMPREPLY=( $(compgen -W "$atalhos atalhos -p --pensar --status --parar --log --config --ajuda" -- "$cur") )
        return
    fi

    # ia log <serviço>: completa com as unidades do systemd.
    if [ "$prev" = "log" ]; then
        local unidades
        unidades=$(systemctl list-units --type=service --all --no-legend --plain 2>/dev/null | awk '{sub(/\.service$/, "", $1); print $1}')
        COMPREPLY=( $(compgen -W "$unidades" -- "$cur") )
        return
    fi

    COMPREPLY=( $(compgen -f -- "$cur") )
}

complete -o filenames -F _ia ia
