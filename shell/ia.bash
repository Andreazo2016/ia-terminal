# Integração do `ia` com o bash. Carregado pelo ~/.bashrc:
#   [ -f ~/.config/ia/ia.bash ] && source ~/.config/ia/ia.bash
#
# Registra o último comando que falhou, para o `ia erro` explicar.
# Guarda só o comando e o código de saída, em ~/.local/state/ia/ultimo_erro.

__ia_estado="${XDG_STATE_HOME:-$HOME/.local/state}/ia"

__ia_registra_erro() {
    local codigo=$?
    # 130 = Ctrl+C, 148 = Ctrl+Z: não são erros de verdade.
    if [ "$codigo" -ne 0 ] && [ "$codigo" -ne 130 ] && [ "$codigo" -ne 148 ]; then
        local cmd
        cmd=$(HISTTIMEFORMAT='' builtin history 1 | sed 's/^ *[0-9]\+\*\? *//')
        case "$cmd" in
            ''|ia|ia\ *) ;;
            *)
                if [ "$cmd" != "$__ia_ultimo_cmd" ]; then
                    mkdir -p -m 700 "$__ia_estado"
                    printf '%s\n%s\n' "$codigo" "$cmd" > "$__ia_estado/ultimo_erro"
                fi
                ;;
        esac
        __ia_ultimo_cmd="$cmd"
    fi
    return "$codigo"
}

case ";${PROMPT_COMMAND};" in
    *";__ia_registra_erro;"*) ;;
    *) PROMPT_COMMAND="__ia_registra_erro${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
