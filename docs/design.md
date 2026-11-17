# Cambio: design

Data: 2026-11-17 · Status: aprovado em 2026-11-17 (com a prévia v2)

## Por que existe

Quem trabalha para o exterior recebe em dólar e precisa acompanhar o câmbio
todo dia. Os apps que existem para isso são complexos, pagos ou as duas
coisas. O Cambio é o oposto: um número na barra de menu do Mac, que se atualiza
sozinho, sem conta, sem anúncio e de graça. O código é aberto para qualquer
pessoa instalar na própria máquina.

## Objetivos

- Bater o olho na barra de menu e saber quanto está a moeda.
- Par de moedas configurável. O padrão é USD → BRL, e dá para escolher qualquer
  par que a API ofereça.
- Instalar fácil, a partir de um release no GitHub, ou compilar a partir do
  código-fonte.
- Ser leve: sem ícone no Dock, quase nada de CPU e memória.

## Fora do escopo da v1

- Alertas de preço-alvo e notificações.
- Vários pares ao mesmo tempo na barra.
- Calculadora de conversão.
- Chave de API própria da AwesomeAPI (sem cache, 100 mil requisições
  grátis). Fica para uma versão futura.
- Mac App Store e Homebrew: na prática, os dois exigem a conta paga da Apple.
- **"Quanto vou receber"**: estimar o valor que cai na conta via Deel, Higlobe
  e afins, com o câmbio e as taxas de cada plataforma. Fica para depois
  da v1, configurável para cada pessoa. Vai ser
  desenhado à parte.

## O que transformaria o app num fracasso

- Ficar complexo como os apps pagos: tela de configuração cheia de opções,
  onboarding, login.
- Rastreamento, analytics ou anúncios.
- Barra vazia ou piscando quando a internet cai.

## Restrições

- macOS 14 ou superior. Swift 6, SwiftUI e nenhuma dependência de terceiros.
- Fonte dos dados: AwesomeAPI, gratuita e sem chave. As respostas sem
  autenticação vêm de cache (de 1 a 5 minutos), o que atende ao pedido
  ("até a cada 5 minutos, sem problemas").
- Sem a conta paga da Apple, o release sai com assinatura ad-hoc. Na
  primeira vez que abrir, quem baixou vê o aviso de "desenvolvedor não
  identificado" e libera em Ajustes → Privacidade e Segurança → Abrir Mesmo
  Assim.

## Abordagens consideradas

| Abordagem | Prós | Contras | Decisão |
|---|---|---|---|
| **App nativo SwiftUI** (`MenuBarExtra`) | Visual nativo, configurável sem mexer em código, leve, sem dependências | Precisa compilar; aviso do Gatekeeper sem conta paga | **Escolhida** |
| Plugin do SwiftBar | Pronto em minutos, script de 15 linhas | Depende do SwiftBar; trocar moeda = editar script; visual só texto | Descartada |
| Electron / Tauri | Multiplataforma | Um navegador inteiro para mostrar um número | Descartada |

## Decisões

- App nativo em SwiftUI.
- Dados da AwesomeAPI, atualizados a cada 30 segundos a 5 minutos.
- O par de moedas é configurável por quem usa o app.
- Repositório em `~/Projects/personal/`, preparado para distribuir como open source.
- Um post no LinkedIn contando a dor que levou a construir o app.

## Como fica (proposta)

Na barra de menu:

```
  USD 5,77 ▾
```

Ao clicar, abre um painel pequeno (validado com uma prévia real rodando na
barra de menu em 2026-11-17):

```
┌──────────────────────────────────┐
│ Dólar Americano → Real Brasileiro│
│ R$ 5,7740           ▼ 0,17% hoje │
│ Hoje: mín 5,7582 · máx 5,8106    │
│ ▁▂▃▂▄▅▄▃▂▃▄▅▆▅▄                  │
│ 30 dias      Atualizado às 11:48 │
├──────────────────────────────────┤
│ (🇺🇸🇧🇷) USD → BRL              ›  │
│        Trocar moeda              │
│ Abrir ao iniciar o Mac     (━●)  │
├──────────────────────────────────┤
│ ↻ Atualizar ⌘R         ⏻ Sair ⌘Q │
└──────────────────────────────────┘
```

"Trocar moeda" abre uma segunda tela no mesmo painel, que desliza da direita
e volta para a direita:

```
┌──────────────────────────────────┐
│ ‹             Moeda              │
│ ┌─ DE ──────────┐┌─ PARA ───────┐│
│ │ (🇺🇸) USD      ⇄ (🇧🇷) BRL     ││
│ │ Dólar Americ. ││ Real Brasil. ││
│ └───────────────┘└──────────────┘│
│ 🔍 Buscar moeda ou país          │
│ Populares                        │
│ (🇺🇸) USD  Dólar Americano     ✓  │
│ (🇪🇺) EUR  Euro                   │
│ Todas as moedas                  │
│ …                                │
└──────────────────────────────────┘
```

- **Barra**: o código da moeda base e o valor com 2 casas, no separador
  decimal do sistema. A seta ▴/▾ (caractere de texto) mostra a direção do
  dia. Na prévia, um ícone SF Symbol na barra não aparecia; o texto aparece.
- **Acabamento** (pedido: "clean, mas com cara de que o
  desenvolvedor teve tempo, dedicação e cuidado"):
  - Cada moeda tem identidade visual própria: bandeira recortada em
    círculo, ou um selo colorido para cripto e metais (₿, Ξ, Au, Ag).
    O par aparece como duas bandeiras sobrepostas, com recorte de verdade,
    sem depender da cor do fundo.
  - O destaque ao passar o mouse é sutil, com cantos arredondados, e não o
    azul sólido de menu. Os botões respondem ao clique na hora (estado
    pressionado).
  - O interruptor e os botões são desenhados à mão, com animação em mola
    sem quique. A tela de moedas entra e sai pelo mesmo caminho.
  - O número grande usa tipografia arredondada com espaçamento levemente
    negativo, e os algarismos têm largura fixa para não "dançar" quando o
    valor muda.
- **Painel**: o valor completo, a variação do dia, um gráfico pequeno dos
  últimos 30 dias (endpoint `daily` da AwesomeAPI, desenhado com Swift
  Charts), a mínima e a máxima do dia e o horário da última atualização.
- **Trocar moeda**: dois cartões, De e Para, com um botão ⇄ entre eles para
  inverter o par. O cartão ativo fica destacado.
  - Escolhido o "De", o foco passa sozinho para o "Para".
  - A lista do "Para" mostra só as moedas que existem em par com o "De" (a API
    tem hoje 540 pares e 162 moedas).
  - A busca funciona por código ou nome e ignora acentos.
  - As seções são "Populares" e "Todas as moedas".
  - Esc ou ‹ voltam para a tela principal.
  - Aparecem também Real Turismo (BRLT) e PTAX (BRLPTAX), úteis para quem
    recebe do exterior.
- **Abrir ao iniciar o Mac**: usa `SMAppService`, sem helper.

## Comportamento (proposta)

- Atualiza a cada 60 segundos, quando o Mac acorda e quando o painel abre.
- Sem internet, mantém o último valor, mostra-o esmaecido e avisa
  "sem conexão" no painel.
- Guarda o último valor, para a barra nunca abrir vazia.
- Interface em inglês e português, seguindo o idioma do sistema.

## Repositório e distribuição (proposta)

```
cambio/
  Package.swift              # Swift Package, abre direto no Xcode
  Sources/Cambio/            # app
  Tests/CambioTests/         # testes de parsing, formatação e pares
  Resources/                 # Info.plist, ícone, en.lproj, pt-BR.lproj
  scripts/build-app.sh       # gera Cambio.app (universal: Apple Silicon + Intel)
  Makefile                   # make run / make app / make install / make zip
  .github/workflows/         # CI: build + testes; release .zip em cada tag
  README.md                  # inglês, com link para a versão em português
  README.pt-BR.md
  LICENSE                    # MIT
  docs/design.md
```

- **Para quem só quer usar**: baixa o `Cambio.zip` na aba Releases do GitHub,
  arrasta o app para Aplicativos e libera na primeira abertura. O README
  explica com prints.
- **Para quem quer compilar**: `make install`.
- Publicar no GitHub (criar o repositório remoto e o primeiro release) fica para depois.

## Chamadas minhas (dá para trocar)

- Nome **Cambio** (provisório).
- Swift Package + script de build, em vez de `.xcodeproj`. O diff fica limpo,
  dá para compilar pelo terminal e o CI fica simples. Abre no Xcode do mesmo
  jeito.
- Licença MIT.
- Atualização a cada 60 segundos.
- Gráfico de 30 dias no painel.
- Interface bilíngue.

## Fica para quem constrói

- O desenho do ícone.
- A regra de casas decimais para pares de valor muito pequeno (ex.: JPY → BRL).
- A organização interna dos arquivos e dos testes.
- O workflow exato do GitHub Actions.
