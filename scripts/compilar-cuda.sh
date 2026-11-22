#!/usr/bin/env bash
# Compila o ggml-cuda.so do llamafile na sua máquina, só para a arquitetura
# da sua GPU NVIDIA. Use quando o llamafile disser:
#   fatal error: support for --gpu nvidia was explicitly requested, but it wasn't available
# e o `--verbose` mostrar "GLIBC_2.38 not found" (ou outra versão).
#
#   scripts/compilar-cuda.sh <arquivo.llamafile> [--arch 75] [-j N]
#
# O resultado vai para a MESMA PASTA do .llamafile, que é o primeiro lugar
# onde o llamafile procura a biblioteca. Requer: git, CUDA toolkit (nvcc), driver.
set -euo pipefail

uso() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
falha() { printf 'erro: %s\n' "$*" >&2; exit 1; }

LLAMAFILE=""; ARCH=""; JOBS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --arch) ARCH="$2"; shift 2 ;;
        -j) JOBS="$2"; shift 2 ;;
        -j*) JOBS="${1#-j}"; shift ;;
        -h|--help|--ajuda) uso ;;
        *) [ -z "$LLAMAFILE" ] && LLAMAFILE="$1" || uso; shift ;;
    esac
done
[ -n "$LLAMAFILE" ] || uso
[ -f "$LLAMAFILE" ] || falha "arquivo não encontrado: $LLAMAFILE"
LLAMAFILE="$(cd "$(dirname "$LLAMAFILE")" && pwd)/$(basename "$LLAMAFILE")"

CUDA_PATH="${CUDA_PATH:-/usr/local/cuda}"
[ -x "$CUDA_PATH/bin/nvcc" ] || falha "nvcc não encontrado em $CUDA_PATH/bin (instale o CUDA toolkit ou defina CUDA_PATH)"
command -v git >/dev/null || falha "precisa do git"

# Versão do llamafile: a biblioteca precisa ser da mesma versão.
VERSAO=$(sh "$LLAMAFILE" --version </dev/null 2>/dev/null | sed -n 's/^llamafile v\{0,1\}\([0-9][0-9.]*\).*/\1/p' | head -1)
[ -n "$VERSAO" ] || falha "não consegui ler a versão de $LLAMAFILE"

# Arquitetura da GPU: compute capability 7.5 -> 75.
if [ -z "$ARCH" ]; then
    command -v nvidia-smi >/dev/null || falha "nvidia-smi não encontrado; informe --arch (ex.: 75)"
    ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d ' .')
fi
[[ "$ARCH" =~ ^[0-9]{2,3}$ ]] || falha "arquitetura inválida: $ARCH"

# Jobs: o nvcc gasta ~2-3 GB de RAM por job.
if [ -z "$JOBS" ]; then
    MEM_GB=$(awk '/MemAvailable/ {print int($2/1024/1024)}' /proc/meminfo)
    JOBS=$(( MEM_GB / 3 )); [ "$JOBS" -lt 1 ] && JOBS=1
    [ "$JOBS" -gt "$(nproc)" ] && JOBS=$(nproc)
fi

FONTE="${XDG_CACHE_HOME:-$HOME/.cache}/ia/llamafile-$VERSAO"
SAIDA="$(dirname "$LLAMAFILE")/ggml-cuda.so"

info "llamafile $VERSAO | GPU sm_$ARCH | $JOBS jobs | CUDA em $CUDA_PATH"
info "código-fonte: $FONTE"
info "saída:        $SAIDA"

if [ ! -d "$FONTE/.git" ]; then
    info "baixando o código-fonte (tag $VERSAO)..."
    mkdir -p "$(dirname "$FONTE")"
    git clone --depth 1 --branch "$VERSAO" --recurse-submodules --shallow-submodules \
        https://github.com/mozilla-ai/llamafile.git "$FONTE"
fi

if [ ! -f "$FONTE/o/.patches-ok" ]; then
    info "aplicando os patches do llamafile no llama.cpp..."
    mkdir -p "$FONTE/o/tmp"
    (cd "$FONTE" && TMPDIR="$FONTE/o/tmp" ./llama.cpp.patches/apply-patches.sh)
    touch "$FONTE/o/.patches-ok"
fi

# Gera uma cópia do cuda.sh que compila só para a arquitetura desta GPU.
# (O original compila para sm_75..sm_120, o que demora várias vezes mais.)
ORIGINAL="$FONTE/llamafile/cuda.sh"
GERADO="$FONTE/llamafile/cuda-sm$ARCH.sh"
python3 - "$ORIGINAL" "$GERADO" "$ARCH" <<'EOF'
import sys
origem, destino, arch = sys.argv[1:]
s = open(origem).read()
inicio = 'if [ "$MINIMAL_ARCHS" = "1" ]; then\n    # Virtual PTX'
fim = "# --compress-mode=size"
if inicio not in s or fim not in s:
    sys.exit("erro: o cuda.sh desta versão mudou; ajuste as arquiteturas à mão em " + origem)
a, b = s.index(inicio), s.index(fim)
novo = (
    f'ARCH_FLAGS="-gencode arch=compute_{arch},code=sm_{arch}"\n'
    "CUDA_VERSION=$(\"$NVCC\" --version | sed -n 's/^.*release \\([0-9]\\+\\.[0-9]\\+\\).*$/\\1/p')\n"
    'CUDA_MAJOR="${CUDA_VERSION%%.*}"\n'
    'CUDA_MINOR="${CUDA_VERSION#*.}"\n\n'
)
open(destino, "w").write(s[:a] + novo + s[b:])
EOF
chmod +x "$GERADO"

info "compilando (pode levar de 10 a 20 minutos)..."
LOG="$FONTE/o/cuda-build.log"
if ! (cd "$FONTE/llamafile" && CUDA_PATH="$CUDA_PATH" ./"$(basename "$GERADO")" "-j$JOBS" --output "$SAIDA.novo") >"$LOG" 2>&1; then
    tail -20 "$LOG" >&2
    falha "a compilação falhou; log completo em $LOG"
fi

if ldd "$SAIDA.novo" 2>&1 | grep -q "not found"; then
    ldd "$SAIDA.novo" | grep "not found" >&2
    falha "a biblioteca gerada tem dependências faltando"
fi
mv "$SAIDA.novo" "$SAIDA"
chmod 755 "$SAIDA"

info "pronto: $SAIDA"
info "teste:  sh \"$LLAMAFILE\" --verbose -ngl 999 --gpu nvidia --cli -p oi -n 5 2>&1 | grep -i cuda"
