# GPU NVIDIA não reconhecida pelo llamafile

## Sintoma

```bash
./modelo.llamafile -ngl 999 --gpu nvidia
# fatal error: support for --gpu nvidia was explicitly requested, but it wasn't available
```

O driver funciona (`nvidia-smi` mostra a placa), mas o llamafile não usa a GPU.

## Diagnóstico

Rode com `--verbose`:

```bash
./modelo.llamafile --verbose -ngl 999 --gpu nvidia --cli -p oi -n 5 2>&1 | grep -i cuda
```

Se aparecer:

```
cuda: INFO: failed to load library ~/.llamafile/v/0.10.6/ggml-cuda.so:
/lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
```

o problema é a **glibc**, não o driver. O llamafile traz uma biblioteca CUDA pronta
(`ggml-cuda.so`), compilada para uma glibc mais nova que a do seu sistema. A versão
Vulkan embutida tem a mesma exigência. Isso acontece, por exemplo, no Ubuntu 22.04
e derivados (Pop!_OS, Mint 21), que usam a glibc 2.35. Para conferir:

```bash
ldd --version | head -1
ldd ~/.llamafile/v/*/ggml-cuda.so | grep "not found"
```

## Solução: compilar a biblioteca na sua máquina

Requisitos: driver NVIDIA, **CUDA toolkit** (`nvcc`, em `/usr/local/cuda` por padrão) e `git`.

```bash
scripts/compilar-cuda.sh ~/.local/share/ia/modelos/Qwen3.5-2B-Q8_0.llamafile
```

O script:

1. lê a versão do llamafile (a biblioteca precisa ser da **mesma versão**);
2. detecta a arquitetura da GPU com `nvidia-smi` (ex.: GTX 1650 = compute 7.5 = `sm_75`);
3. baixa o código-fonte dessa versão e aplica os patches do llamafile no llama.cpp;
4. compila **só para a sua arquitetura**, o que é bem mais rápido que o build oficial,
   feito para todas as arquiteturas;
5. coloca o `ggml-cuda.so` **na mesma pasta do `.llamafile`**.

Em uma GTX 1650 com 16 GB de RAM, levou cerca de 12 minutos.

## A pegadinha: onde colocar a biblioteca

Copiar para `~/.llamafile/v/<versão>/ggml-cuda.so` **não funciona**: a cada execução,
o llamafile extrai de novo a biblioteca embutida e sobrescreve o arquivo.

A ordem de busca, segundo `llamafile_try_load_prebuilt_dso()` em `llamafile/llamafile.c`, é:

1. **pasta do executável** (`<pasta do .llamafile>/ggml-cuda.so`) ← use esta
2. a biblioteca embutida, extraída para `~/.llamafile/v/<versão>/`
3. `~/.llamafile/v/<versão>/ggml-cuda.so`
4. `~/ggml-cuda.so`

Para confirmar que deu certo:

```
cuda: INFO: loaded library .../ggml-cuda.so from executable directory
Device 0: NVIDIA GeForce GTX 1650, compute capability 7.5
load_tensors: offloaded 25/25 layers to GPU
```

Se trocar a versão do llamafile, compile de novo.

## Outras pegadinhas

- **`Exec format error` ao chamar o llamafile de um programa:** ele é um binário APE
  (Actually Portable Executable). O kernel não o executa direto; o bash consegue porque
  cai para o modo shell. Inicie com `sh arquivo.llamafile ...`. O `ia` já faz isso.
- **Rodar um `.gguf` com o executável de outro `.llamafile`** dá
  `mismatch between text model ... and mmproj`. Os argumentos embutidos no llamafile
  (arquivo `.args` dentro dele) apontam para o componente de visão do modelo original.
  Passe `--mmproj "" --no-mmproj` depois do `-m`. O `ia` já faz isso.
