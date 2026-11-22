#!/usr/bin/env bash
# Demonstração do `ia` para gravar a tela: digita os comandos "ao vivo" e
# executa de verdade. Veja demo/roteiro.md.
#
#   demo/demo.sh            roda todas as cenas
#   demo/demo.sh 3          começa na cena 3
#   VELOCIDADE=0.02 demo/demo.sh   digitação mais rápida (padrão 0.04 s/tecla)
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
TMP="$AQUI/tmp"
VELOCIDADE="${VELOCIDADE:-0.04}"
INICIO="${1:-1}"

# ---------------------------------------------------------------- preparação

preparar() {
    rm -rf "$TMP"; mkdir -p "$TMP"
    cat > "$TMP/notas-reuniao.txt" <<'EOF'
Reunião de planejamento - sprint 14

Participantes: equipe de backend e produto.

O time decidiu adiar a migração do banco de dados para a próxima sprint,
porque os testes de carga mostraram lentidão nas consultas de relatório.
Até lá, a prioridade é corrigir o bug de login no aplicativo móvel, que
afeta cerca de 8% dos usuários. Também foi aprovado o novo fluxo de
cadastro, com entrega prevista para o dia 15. O orçamento de infraestrutura
continua o mesmo, e a equipe vai avaliar a troca do provedor de e-mail
no próximo mês. Próxima reunião: quinta-feira, às 10h.
EOF
    mkdir -p "$TMP/app" && cd "$TMP/app"
    git init -q
    git config user.name "Demo" && git config user.email "demo@example.com"
    printf 'timeout = 30\n' > app.cfg
    printf 'def conectar():\n    return abrir(timeout=30)\n' > rede.py
    git add . && git commit -qm "feat: configuração inicial da conexão"
    printf 'timeout = 60\nretries = 3\n' > app.cfg
    printf 'def conectar():\n    for tentativa in range(3):\n        try:\n            return abrir(timeout=60)\n        except TimeoutError:\n            continue\n    raise TimeoutError("sem conexão")\n' > rede.py
    git add .
}

# ---------------------------------------------------------------- efeitos

prompt() { printf '\033[1;32m~/app\033[0m \033[1;34m$\033[0m '; }

digitar() {
    local texto="$1" i
    for (( i=0; i<${#texto}; i++ )); do
        printf '%s' "${texto:$i:1}"
        sleep "$VELOCIDADE"
    done
    sleep 0.4
    printf '\n'
}

# cena "comando" [pausa_depois]
cena() {
    prompt
    digitar "$1"
    eval "$1"
    sleep "${2:-2.5}"
    printf '\n'
}

titulo() { printf '\033[2m# %s\033[0m\n' "$1"; sleep 1; }

# ---------------------------------------------------------------- roteiro

preparar
cd "$TMP/app"
printf 'aquecendo o modelo...'
ia "oi" </dev/null >/dev/null 2>&1
clear

n=0
proxima() { n=$((n+1)); [ "$n" -ge "$INICIO" ]; }

if proxima; then
    titulo "IA local, na GPU, direto no terminal"
    cena 'ia "quanto é 3 mais 3"'
fi
if proxima; then
    titulo "Tradução por pipe"
    cena 'echo "The deploy failed because the disk was full." | ia traduz'
fi
if proxima; then
    titulo "Resumo de um arquivo"
    cena 'ia resumo < ../notas-reuniao.txt' 4
fi
if proxima; then
    titulo "Explica um comando antes de rodar"
    cena 'ia explica "tar -xzvf backup.tar.gz -C /tmp"' 4
fi
if proxima; then
    titulo "Mensagem de commit a partir do diff (responda: c)"
    cena 'git diff --staged --stat' 1.5
    cena 'ia commit' 1
    cena 'git log --oneline -2' 3
fi
if proxima; then
    titulo "Modo -p: raciocina antes de responder"
    cena 'ia -p "Comprei 3 camisetas a R$ 25 e paguei com R$ 100. Qual o troco?"' 3
fi
if proxima; then
    titulo "Tudo rodando localmente na GPU"
    cena 'nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv' 4
fi
