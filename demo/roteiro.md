# Roteiro da demonstração

O objetivo é um vídeo curto de 40 a 60 segundos: em poucos segundos, quem vê o post entende o
que o `ia` faz. O `demo.sh` digita os comandos "ao vivo" e executa de verdade, então
você só precisa gravar a tela.

## Antes de gravar

1. **Terminal limpo:** fonte grande (16 a 18 pt), tema escuro, janela de ~100×30 colunas.
   Feche abas e esconda a barra de favoritos e as notificações (modo "não perturbe").
2. **Nada pessoal na tela:** o prompt do `demo.sh` mostra só `~/app $`. Confira que o
   título da janela não mostra o seu usuário ou o nome da máquina. Se mostrar, troque pelo
   menu do terminal ou com `printf '\033]0;ia\007'`.
3. **Aqueça o modelo:** o `demo.sh` já faz uma pergunta antes da primeira cena, para não
   aparecer o carregamento de 2 s.
4. Faça um ensaio sem gravar: `demo/demo.sh`.

## Cenas

| # | Comando | Mostra | Tempo |
|---|---|---|---|
| 1 | `ia "quanto é 3 mais 3"` | resposta direta e instantânea | ~3 s |
| 2 | `echo "The deploy failed..." \| ia traduz` | pipe + atalho | ~4 s |
| 3 | `ia resumo < notas-reuniao.txt` | lê um arquivo e resume | ~8 s |
| 4 | `ia explica "tar -xzvf ..."` | explica um comando | ~8 s |
| 5 | `git diff --staged --stat` → `ia commit` → **tecle `c`** → `git log` | o atalho mais "uau" | ~10 s |
| 6 | `ia -p "...troco?"` | modo raciocínio acertando a conta | ~8 s |
| 7 | `nvidia-smi --query-gpu=...` | prova que roda local, na GPU | ~4 s |

Na cena 5, o `ia commit` pergunta `[c]ommitar, [e]ditar antes, [S]air`: tecle **c** e Enter.
Ele commita no repositório de demonstração criado em `demo/tmp/app`, nunca no seu.

Para regravar a partir de uma cena: `demo/demo.sh 5`.
Para digitar mais rápido: `VELOCIDADE=0.02 demo/demo.sh`.

> As respostas do modelo variam um pouco a cada execução. Se uma cena sair ruim, grave de novo
> só ela e junte os trechos depois.

## Gravando

**Opção A: o gravador do GNOME (Pop!_OS 22.04 / Ubuntu 22.04)**

1. Tecle `Print Screen`, escolha **Gravar tela** (ícone de câmera) e selecione só a janela
   do terminal.
2. Rode `demo/demo.sh` e, no fim, clique no botão vermelho da barra superior para parar.
3. O vídeo fica em `~/Vídeos/Screencasts/` em formato `.webm`.

**Opção B: ffmpeg, gravando uma área da tela**

```bash
# ajuste o tamanho e a posição (+x,y) para a área da janela do terminal
ffmpeg -f x11grab -framerate 30 -video_size 1280x720 -i :0.0+100,100 demo.mp4
# Ctrl+C para parar
```

## Convertendo

**Para o LinkedIn,** use vídeo MP4: ele toca sozinho no feed e tem qualidade melhor que GIF.

```bash
ffmpeg -i gravacao.webm -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart demo.mp4
```

**Para o README do GitHub,** use GIF, que roda sem player:

```bash
ffmpeg -i gravacao.webm -vf "fps=12,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" docs/demo.gif
```

Se o GIF passar de ~10 MB, reduza `fps` para 10 ou `scale` para 800.

## Depois de gravar

- Assista uma vez procurando dados pessoais (usuário, e-mail, caminhos, notificações).
- Apague o repositório de demonstração: `rm -rf demo/tmp`.
