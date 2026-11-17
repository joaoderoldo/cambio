# Cambio: quanto eu recebo (plataformas)

Data: 2026-11-17 · Status: aprovado em 2026-11-17 (visual aprovado com a prévia do mesmo dia)

## Por que existe

Quem recebe do exterior não recebe a cotação comercial. Cada plataforma (Deel,
Higlobe, Wise…) aplica a sua taxa e o seu câmbio, e a diferença entre elas
pode passar de 2% do valor. Cada pessoa usa as suas próprias plataformas,
então a lista precisa ser configurável.

## Objetivos

- No painel, ver o "dólar" de cada plataforma comparado com o comercial.
- Uma aba "Quanto recebo" para digitar um valor e ver quanto cai em cada
  plataforma.
- Cada pessoa cadastra as suas plataformas: a partir de modelos prontos, de
  uma personalizada, ou ajustando pela cotação que a plataforma mostra.

## Fora do escopo desta versão

- Buscar o câmbio direto da plataforma: nenhuma tem API pública, e acessar a
  conta exigiria login.
- Saldo da conta, histórico de recebimentos, notificações.
- Rotas entre plataformas (por exemplo, Deel → Higlobe por US$ 5).
- Impostos locais (IOF etc.) como item separado. Quando existirem, entram no
  spread.

## O que transformaria a feature num fracasso

- Dizer qual plataforma é "a melhor": muitas vezes quem recebe não escolhe
  a plataforma.
- Publicar números chutados de plataformas que não medimos.
- Complicar o app de quem só quer a cotação: sem plataforma configurada, nada
  disso aparece além de uma entrada discreta.

## Restrições

- Mesmas da v1: macOS 14+, Swift 6, nenhuma dependência de terceiros,
  nenhuma rede além da AwesomeAPI, dados só no Mac da pessoa.
- Os valores são **estimativas**. A interface diz isso, e o README também.

## Abordagens consideradas

| Abordagem | Decisão |
|---|---|
| **Estender o Cambio dentro da arquitetura atual**: modelo e cálculo no `CambioCore` (testados), páginas novas no painel | **Escolhida**: é o único caminho que mantém tudo num painel só e testável |
| Uma janela ou app separado de calculadora | Descartada: quebra a simplicidade de "tudo num painel" |
| Ler o câmbio das plataformas (API ou scraping logado) | Descartada: não existe API pública, e exigiria credenciais da pessoa |

## Decisões

- Mostrar no painel o dólar de cada plataforma em comparação com o atual.
- Ter uma aba para digitar o valor e ver quanto recebe.
- Plataformas configuráveis por cada usuário, com Deel e Higlobe como modelos.
- O visual da prévia de 2026-11-17: seção "Recebendo via", "Quanto recebo",
  "Plataformas", "Adicionar plataforma" e "Editar".

## Modelo de cálculo

Para um valor `A` na moeda de origem e a cotação comercial `C` do par:

```
recebe = max(0, A × (1 − taxa%) − taxaFixa) × C × (1 − spread%)
```

| Plataforma (medida em 2026-11-17) | taxa% | taxaFixa | spread% | Como foi medido |
|---|---|---|---|---|
| Deel · Pix (USD → BRL) | 1,2 | 0 | 1,0 | 5 simulações de US$ 100 a 5.000 (taxa exatamente 1,2%); câmbio 0,9–1,3% abaixo do comercial |
| Higlobe · Pix (USD → BRL) | 0 | 0 | 0,2 | Simulações e recibos de saque; o recibo mostra "spread 0,20%" sobre a cotação base |

- **"Dólar da plataforma"** (a seção do painel): `C × (1 − taxa%) × (1 − spread%)`.
  A taxa fixa fica fora porque o efeito dela depende do valor; ela aparece na
  aba "Quanto recebo".
- **Custo %**: `1 − dólarDaPlataforma / C`.
- **Ajuste pela cotação de agora**: `spread% = (1 − cotaçãoDaPlataforma / C) × 100`,
  em que `C` é o comercial do mesmo par buscado na hora (atualizado se tiver
  mais de 60 s). O resultado fica entre 0 e 20% e é arredondado para 2 casas.

## Como fica

Igual à prévia aprovada (imagens da prévia de 2026-11-17):

- **Painel:**
  - A seção "Recebendo via" fica entre o gráfico e "Trocar moeda". Cada
    plataforma ocupa uma linha com selo, nome, método, `R$ 5,66` e `−2,2%`.
  - "Simular ›" abre a aba.
  - Sem plataformas, a seção some, e no lugar dela aparece uma linha discreta
    "Quanto vou receber? ›" que leva à mesma aba (chamada minha).
- **Quanto recebo:**
  - O valor fica num cartão destacado (moeda de origem com bandeira), com
    atalhos de 1.000, 2.000, 5.000 e 10.000.
  - Embaixo, a lista "Você recebe": o comercial como referência, em cinza;
    depois cada plataforma, ordenada pelo valor recebido, com a perda em reais.
  - No rodapé, uma nota de estimativa e o link "Editar plataformas".
  - O último valor digitado fica salvo.
- **Plataformas:** a lista das cadastradas mais "Adicionar plataforma".
- **Adicionar:** os modelos Deel · Pix e Higlobe · Pix, com a nota "medidos em
  nov/2026", e a opção "Personalizada".
- **Editar:**
  - Campos: nome, método, moedas (escolhidas com o seletor de moedas que já
    existe), taxa %, taxa fixa e spread %.
  - O bloco "Ajustar pela cotação de agora" tem um campo e o botão "Aplicar".
  - "Remover plataforma" pede confirmação no próprio botão.
- **Identidade:** plataformas são quadrados arredondados com a inicial e a cor
  da plataforma; moedas continuam sendo círculos. Deel é roxo, Higlobe é
  vermelho, e a personalizada usa uma cor de uma pequena paleta.

## Dados e cotações

- As plataformas ficam salvas no `SettingsStore` (chave `cambio.platforms`,
  em JSON), e o último valor da aba fica em `cambio.calculatorAmount`.
- O `RateStore` passa a manter as cotações de todos os pares em uso: o da
  barra mais os das plataformas. Elas vêm **numa única requisição**
  (`/json/last/USD-BRL,EUR-BRL`). No caso mais comum (USD → BRL na barra e nas
  plataformas) não há requisição a mais.
- Se a pessoa tiver plataformas com moedas de origem diferentes, o cartão de
  valor ganha um seletor de moeda, e a lista mostra só as plataformas daquela
  moeda.

## Chamadas minhas (dá para trocar)

- A linha "Quanto vou receber? ›" para quem ainda não tem plataformas.
- A taxa fixa fica fora do "dólar da plataforma" e entra só na simulação.
- Spread limitado entre 0 e 20% no ajuste automático.
- Remover pede confirmação no próprio botão, em vez de um diálogo.
- Os modelos prontos são só os dois que medimos, com data.

## Fica para quem constrói

- Os detalhes visuais finos já resolvidos na prévia (tamanhos, paddings,
  molas).
- A paleta de cores das personalizadas.
- A validação dos campos (vírgula ou ponto, valores negativos).
- A organização dos testes.
