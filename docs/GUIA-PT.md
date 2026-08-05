# Guia rapido

Este e o equivalente seguro para Star Citizen: externo, reversivel, e sem DLL hook dentro do jogo.

## Antes de abrir o jogo

1. Deixa estes ficheiros fora da pasta do jogo, por exemplo em `Documentos\StarCitizenTripleScreen` ou `C:\Tools\StarCitizenTripleScreen`.
2. Nao metas o script em `LIVE\Bin64`, na pasta do Easy Anti-Cheat, nem na pasta do RSI Launcher.
3. Mantem NVIDIA Surround desligado.
4. Abre o **Painel de Controlo NVIDIA** e entra em **Gerir definicoes 3D >
   Definicoes globais > Fatores DSR**.
5. Ativa o fator `1.78x` que disponibiliza `2560x1440` num monitor nativo
   `1920x1080`. Conforme o driver, pode aparecer como `1.78x DL` (DLDSR) ou
   apenas `1.78x` (DSR tradicional). Carrega **Aplicar**.
6. Abre **Definicoes do Windows > Sistema > Ecra**, seleciona cada monitor
   lateral e escolhe **Resolucao do ecra = 2560x1440**.
7. Mantem o monitor central em 2560x1440 nativo.
8. Ainda em Sistema > Ecra, escolhe cada monitor e define **Escala = 100% nos tres**.
9. No Windows, alinha os tres monitores pelo topo e deixa o central como principal.
10. Confirma que `StarCitizenTripleScreen.ini` esta assim:

Se `2560x1440` nao aparecer num monitor lateral, volta aos Fatores DSR e confirma
que `1.78x` ficou ativo antes de arrancares o wrapper.

```ini
[Layout]
Mode=Manual
X=-2560
Y=0
Width=7680
Height=1440
```

E confirma tambem:

```ini
[UserCfg]
WindowMode=0
```

O `0` mantem o renderer em janela normal; o wrapper retira a moldura por fora.
No teste de 5 de agosto de 2026, o valor `2` foi identificado pelo proprio
`Game.log` como `Borderless` e deixou o render interno achatado com espaco preto.

Para corrigir o cursor preso num unico monitor, mantem tambem:

```ini
[Input]
RepairCursorClip=true
```

O wrapper apenas expande o retangulo normal de captura do cursor do Windows para
o alvo completo. Nao le nem altera memoria do Star Citizen.

## Imagem demasiado alta ou cortada

Se o log mostrar que o Star Citizen muda repetidamente a janela para `8960x1800`,
os monitores laterais estao em Escala 125% enquanto o central esta em 100%.
Mantem a resolucao efetiva 2560x1440, mas muda **Escala para 100%** nos laterais.
Nao alteres `Height=1440`: o problema e DPI misto, nao a resolucao de render.

## Arranque recomendado

1. Corre `Run-StarCitizenTripleScreen.cmd`.
2. Abre o RSI Launcher normalmente.
3. Carrega Play no Star Citizen.
4. O script espera pelo `StarCitizen.exe`, remove a moldura da janela e aplica `7680x1440` em `X=-2560`.

Se o jogo recriar a janela ao iniciar o renderer, o identificador da janela muda.
O wrapper volta a localizar a nova janela e continua automaticamente.

O unico ficheiro dentro da pasta do jogo que o script deve mexer e `StarCitizen\LIVE\USER.cfg`. Esse ficheiro e uma configuracao normal do Star Citizen.

Se o Star Citizen ficar a lutar contra o tamanho da janela, o script para depois de um numero limitado de correcoes. Isto e de proposito, para nao repetir o loop que tivemos com ferramentas genericas.

## Desfazer

Para restaurar o ultimo `USER.cfg` guardado:

```powershell
.\StarCitizenTripleScreen.ps1 -RestoreUserCfg
```

Para testar sem mexer no `USER.cfg`:

```powershell
.\StarCitizenTripleScreen.ps1 -NoUserCfg
```

Para validar apenas configuracao e escrita num ambiente de teste, usa o teste
incluido em `tests\Test-StarCitizenTripleScreen.ps1`; ele nao abre o jogo.

## Nota importante

Isto nao promete "anti-cheat invisivel". A ideia e precisamente o contrario: nada de injecao, nada de memoria do jogo, nada de bypass. E so configuracao e gestao da janela pelo Windows.
