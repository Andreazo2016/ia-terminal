#!/usr/bin/env bash
# Instala o comando `ia` nos diretórios padrão do usuário (XDG). Não usa sudo.
#
#   ./install.sh                instala o comando, os atalhos e o autocompletar
#   ./install.sh --baixar       também baixa o modelo Qwen3.5-2B (~2,9 GB)
#   ./install.sh --remover      remove o comando (mantém configuração e modelos)
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ia"
DADOS="${XDG_DATA_HOME:-$HOME/.local/share}/ia"
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/ia"
COMPLETAR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"

MODELO_REPO="mozilla-ai/llamafile_0.10"
MODELO_ARQ="Qwen3.5-2B-Q8_0.llamafile"

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }

remover() {
    "$BIN/ia" --parar >/dev/null 2>&1 || true
    rm -f "$BIN/ia" "$COMPLETAR/ia"
    info "comando removido. Configuração em $CONFIG e modelos em $DADOS foram mantidos."
    info "se adicionou o gancho ao ~/.bashrc, apague a linha que carrega $CONFIG/ia.bash"
}

baixar_modelo() {
    local destino="$DADOS/modelos/$MODELO_ARQ"
    if [ -f "$destino" ]; then
        info "modelo já existe: $destino"
        return
    fi
    command -v curl >/dev/null || { echo "precisa do curl" >&2; exit 1; }
    info "consultando o checksum do modelo..."
    local sha
    sha=$(curl -fsS "https://huggingface.co/api/models/$MODELO_REPO/tree/main" \
        | python3 -c "import json,sys; print(next(f['lfs']['oid'] for f in json.load(sys.stdin) if f['path']=='$MODELO_ARQ'))")
    info "baixando $MODELO_ARQ (~2,9 GB)..."
    curl -fL --progress-bar -o "$destino.part" \
        "https://huggingface.co/$MODELO_REPO/resolve/main/$MODELO_ARQ"
    echo "$sha  $destino.part" | sha256sum -c --quiet -
    mv "$destino.part" "$destino"
    chmod 755 "$destino"
    info "modelo pronto: $destino"
}

case "${1:-}" in
    --remover) remover; exit 0 ;;
    --baixar|"") ;;
    *) echo "uso: $0 [--baixar | --remover]" >&2; exit 2 ;;
esac

command -v python3 >/dev/null || { echo "precisa do python3" >&2; exit 1; }

install -d -m 700 "$CONFIG" "$DADOS" "$DADOS/modelos" "$ESTADO"
install -d "$BIN" "$COMPLETAR"

install -m 755 "$AQUI/bin/ia" "$BIN/ia"
install -m 644 "$AQUI/shell/ia.completion.bash" "$COMPLETAR/ia"
install -m 600 "$AQUI/shell/ia.bash" "$CONFIG/ia.bash"
for f in config.ini atalhos.ini; do
    if [ -f "$CONFIG/$f" ]; then
        info "mantido o seu $CONFIG/$f (o novo ficou em $CONFIG/$f.novo)"
        install -m 600 "$AQUI/config/$f" "$CONFIG/$f.novo"
    else
        install -m 600 "$AQUI/config/$f" "$CONFIG/$f"
    fi
done
info "comando instalado em $BIN/ia"

[ "${1:-}" = "--baixar" ] && baixar_modelo

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) info "atenção: $BIN não está no PATH; adicione ao ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

cat <<EOF

Próximos passos:
  1. Modelo: rode './install.sh --baixar' ou coloque um .llamafile em
     $DADOS/modelos/ e ajuste 'modelo' em $CONFIG/config.ini
  2. Para o 'ia erro' saber qual comando falhou, adicione ao ~/.bashrc:
       [ -f $CONFIG/ia.bash ] && source $CONFIG/ia.bash
  3. Teste:  ia "quanto é 3 mais 3"   |   ia atalhos

GPU NVIDIA não detectada pelo llamafile? Veja docs/gpu.md
EOF
