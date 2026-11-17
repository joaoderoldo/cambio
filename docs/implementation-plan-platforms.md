# Cambio: plano de implementação de "Quanto eu recebo" (plataformas)

**Objetivo:** mostrar, por plataforma (Deel, Higlobe ou outra que a pessoa
cadastrar), o câmbio efetivo comparado com o comercial, e uma aba que calcula
quanto cai na conta para um valor digitado.

**Arquitetura:**
- **Núcleo, em `CambioCore`, testado:** o modelo `Platform`, as contas puras
  em `Payout`, a leitura de números digitados e o `PlatformStore` (estado
  persistido).
- **Cotações:** o `RateStore` passa a buscar numa única requisição o par da
  barra e os pares das plataformas. Se essa requisição falhar, tenta só o par
  da barra.
- **App:** ganha páginas novas no painel. A navegação vira uma pilha, e o
  seletor de moedas passa a ser reutilizável.

**Stack:** igual à v1: Swift 6, SwiftUI, Observation, Swift Testing, nenhuma
dependência de terceiros.

**Design:** `docs/design-platforms.md`, aprovado em 2026-11-17. A referência
visual aprovada é a prévia:
- código em uma prévia descartável, fora do repositório;
- imagens em uma prévia descartável, fora do repositório.

Os valores visuais vêm de lá. A lógica é reescrita com testes.

## Restrições globais

- macOS 14+, Swift 6, nenhuma dependência de terceiros. A única rede continua
  sendo a AwesomeAPI, e os dados ficam só no Mac.
- Fórmula: `recebe = max(0, A × (1 − taxa%) − taxaFixa) × C × (1 − spread%)`.
- "Dólar da plataforma" = `C × (1 − taxa%) × (1 − spread%)`.
- Custo % = `(1 − (1 − taxa%)(1 − spread%)) × 100`.
- Ajuste pela cotação: `spread% = (1 − cotação / C) × 100`, limitado a
  0…20 e arredondado para 2 casas. Dá `nil` se `C` ou a cotação não forem
  positivos.
- Modelos prontos, ambos com a nota "medidos em nov/2026":
  - Deel · Pix: taxa 1,2%, fixa 0, spread 1,0%, roxo;
  - Higlobe · Pix: taxa 0%, fixa 0, spread 0,2%, vermelho.
- Chaves no `SettingsStore`: `cambio.platforms` (JSON) e
  `cambio.calculatorAmount` (padrão 1000).
- Atalhos de valor na aba: 1.000, 2.000, 5.000 e 10.000.
- Sem plataformas, a seção some e no lugar aparece a linha "Quanto vou
  receber? ›".
- Remover pede confirmação no próprio botão.
- Sem selo de "melhor plataforma".
- Toda frase nova tem tradução EN e pt-BR.
- Commits locais no padrão Conventional Commits, sem trailers e sem push.

## Pontos de atenção na revisão

1. **Números digitados em formatos diferentes:**
   - "5,72386", "5.72386", "1.000,50" e "1,000.50" precisam ser lidos
     corretamente;
   - lixo como "abc" ou "1,2,3" não pode ser salvo.

   Teste na Task 1.
2. **Um par de plataforma que a API não conhece** faz a requisição em lote
   inteira dar 404 (conferido na API real em 2026-11-17). Nesse caso a barra
   continua funcionando, porque o app faz uma nova requisição só com o par
   dela. Teste na Task 3.
3. **Taxa fixa maior que o valor digitado:** o resultado é R$ 0, nunca
   negativo. Teste na Task 1.
4. **Ajuste sem cotação comercial** (sem internet) **ou com cotação da
   plataforma maior que a comercial:**
   - sem cotação, o botão "Aplicar" fica desabilitado;
   - com spread negativo, o valor vira 0.

   Testes nas Tasks 1 e 5.
5. **Remover todas as plataformas:** a seção some, a aba continua mostrando o
   comercial e o botão "Adicionar", e o último valor digitado continua salvo.
   Teste na Task 2.

---

## Arquivos

```
Sources/CambioCore/
  Platform.swift          # Platform, PlatformColor, templates, validação
  Payout.swift            # contas puras
  DecimalInput.swift      # leitura de número digitado (vírgula ou ponto)
  PlatformStore.swift     # @Observable, persistido
  AwesomeAPI.swift        # + decodeLatest(_:pairs:) e latestURL(for: [CurrencyPair])
  RateClient.swift        # + latest(_ pairs:)
  RateStore.swift         # + extraPairs, quotes, quote(for:)
Sources/Cambio/Views/
  NavBar.swift            # extraído do PickerPage
  PanelView.swift         # pilha de páginas
  PickerPage.swift        # initial + onSelect (reutilizável)
  MainPage.swift          # seção ou linha de entrada
  Platforms/PlatformBadge.swift, ReceivingSection.swift, CalculatorPage.swift,
  Platforms/PlatformsPage.swift, AddPlatformPage.swift, EditPlatformPage.swift
Sources/Cambio/CambioApp.swift, Snapshot.swift
Resources/{en,pt-BR}.lproj/Localizable.strings
Tests/CambioCoreTests/PlatformTests.swift, PayoutTests.swift, DecimalInputTests.swift,
  PlatformStoreTests.swift, (RateStoreTests, AwesomeAPITests, Fakes) atualizados
```

---

### Task 1: Modelo `Platform`, contas e leitura de números

**Arquivos:** `Platform.swift`, `Payout.swift` e `DecimalInput.swift` em
`Sources/CambioCore/`, com os testes correspondentes.

**Interfaces produzidas:**
```swift
public enum PlatformColor: String, Codable, CaseIterable, Sendable {
    case purple, red, blue, green, orange, teal, graphite
    public var rgb: (red: Double, green: Double, blue: Double) { get }
}
public struct Platform: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var method: String
    public var pair: CurrencyPair
    public var feePercent: Double
    public var fixedFee: Double
    public var spreadPercent: Double
    public var color: PlatformColor
    public init(id: UUID = UUID(), name: String, method: String, pair: CurrencyPair,
                feePercent: Double, fixedFee: Double, spreadPercent: Double, color: PlatformColor)
    public var monogram: String          // primeira letra do nome, minúscula; "?" se vazio
    public var isValid: Bool             // nome não vazio; taxa 0...50; fixa ≥ 0; spread 0...50
    public static let deelPix: Platform  // 1.2 / 0 / 1.0, .purple, USD-BRL
    public static let higlobePix: Platform // 0 / 0 / 0.2, .red, USD-BRL
    public static func custom(color: PlatformColor) -> Platform // nome "", método "Pix", USD-BRL, zeros
    public func instantiated() -> Platform // cópia com id novo (usada ao adicionar de um modelo)
}
public enum Payout {
    public static func receive(_ amount: Double, via platform: Platform, commercial: Double) -> Double
    public static func platformRate(_ platform: Platform, commercial: Double) -> Double
    public static func costPercent(_ platform: Platform) -> Double
    public static func spread(platformRate: Double, commercial: Double) -> Double?
}
public enum DecimalInput {
    public static func parse(_ text: String, locale: Locale = .current) -> Double?
}
```
- **Regra do `DecimalInput.parse`:**
  - Espaços e "R$", "US$", "%" são ignorados.
  - Se aparecerem vírgula e ponto, o **último** que aparece é o decimal, e o
    outro é separador de milhar.
  - Se aparecer um só tipo:
    - quando é o separador decimal do locale, é decimal;
    - quando é o de milhar do locale, só conta como milhar se todo grupo
      depois dele tiver exatamente 3 dígitos ("5.000" = 5000 em pt_BR). Se
      não tiver, é decimal ("5.72386" = 5,72386 em pt_BR).
  - Mais de um separador decimal, ou qualquer outro caractere, dá `nil`.

- [ ] **1.1** Escrever os testes. Os valores são exatos e usam tolerância
  `abs(a - b) < 1e-9` quando o resultado é `Double`.
  - `payoutDeelMatchesRealSimulation`:
    `receive(5000, via: .deelPix, commercial: 5.7817)` ≈ `5000 × 0.988 × 5.7817 × 0.99`.
  - `payoutHiglobeSpreadOnly`:
    `receive(1000.00, via: .higlobePix, commercial: 5.4881)` ≈
    `1000.00 × 5.4881 × 0.998`, a menos de R$ 0,01 de 5477.12.
  - `fixedFeeNeverNegative`: com uma plataforma de taxa fixa 50, `receive(10, …)` dá `0`.
  - `platformRateAndCost`:
    - `platformRate(.deelPix, commercial: 5.78)` ≈ `5.78 × 0.988 × 0.99`;
    - `costPercent(.deelPix)` ≈ `2.188`;
    - `costPercent(.higlobePix)` ≈ `0.2`.
  - `spreadFromRate`:
    - `spread(platformRate: 5.72386, commercial: 5.7817) == 1.0`;
    - `spread(platformRate: 5.9, commercial: 5.78) == 0` (negativo vira 0);
    - `spread(platformRate: 1, commercial: 5.78) == 20` (limite de 20);
    - com comercial 0 dá `nil`, e com cotação -1 também dá `nil`.
  - `parsesDecimals`, com `(texto, esperado)` como argumentos e locale `pt_BR`:
    `("5,72386", 5.72386)`, `("5.72386", 5.72386)`, `("1.000,50", 1000.5)`,
    `("1,000.50", 1000.5)`, `("1,2", 1.2)`, `(" 1,20 % ", 1.2)`,
    `("US$ 5.000", 5000)`, `("12", 12)`.
  - `rejectsGarbage`: `"abc"`, `"1,2,3,4"`, `""` e `"5..2"` dão `nil`.
  - `parsesEnUS`: `parse("5.000", locale: en_US) == 5.0` e
    `parse("5,000", locale: en_US) == 5000`.
  - `platformValidityAndMonogram`:
    - `.deelPix.isValid`;
    - com nome vazio é inválido;
    - com taxa 60 é inválido;
    - `.deelPix.monogram == "d"`.
  - `platformCodableRoundTrip` e `instantiatedHasNewId`.
- [ ] **1.2** Rodar `swift test`. Esperado: falha de compilação (os tipos não existem).
- [ ] **1.3** Implementar os três arquivos.
- [ ] **1.4** Rodar `swift test`. Esperado: todos passam, sem avisos.
- [ ] **1.5** Commit `feat(core): platform model, payout math and decimal input`.

### Task 2: `PlatformStore`

**Arquivos:** `Sources/CambioCore/PlatformStore.swift` e `Tests/CambioCoreTests/PlatformStoreTests.swift`.

**Interfaces produzidas:**
```swift
@MainActor @Observable
public final class PlatformStore {
    public private(set) var platforms: [Platform]
    public var calculatorAmount: Double { get set }       // persiste ao mudar; padrão 1000; negativo vira 0
    public init(settings: any SettingsStore = UserDefaults.standard)
    public func add(_ platform: Platform)                  // adiciona no fim; ignora se inválida
    public func update(_ platform: Platform)               // troca pelo id; ignora se inválida ou id desconhecido
    public func remove(id: UUID)
    public func platform(id: UUID) -> Platform?
    public var pairs: Set<CurrencyPair> { get }
    public var baseCurrencies: [String] { get }            // ordem da 1ª aparição, sem repetir
}
```
- [ ] **2.1** Escrever os testes, todos com `InMemorySettings`:
  - `startsEmptyWithDefaultAmount`: começa sem plataformas e com
    `calculatorAmount == 1000`.
  - `addPersistsAndRestores`: depois de `add(.deelPix.instantiated())` e
    `add(.higlobePix.instantiated())`, um segundo store com as mesmas
    settings tem 2 plataformas, na mesma ordem.
  - `rejectsInvalid`: `add` de uma plataforma de nome vazio não muda nada.
  - `updateReplacesById`: trocar o spread da Deel para 1.04 persiste.
  - `removeAllKeepsAmount` (ponto de atenção 5): com o valor em 5000,
    adicionar e remover tudo deixa a lista vazia, e um store recarregado
    continua com 5000.
  - `pairsAndBases`: Deel (USD-BRL) e uma personalizada EUR-BRL dão
    `pairs.count == 2` e `baseCurrencies == ["USD","EUR"]`.
  - `negativeAmountClampsToZero`.
- [ ] **2.2** Rodar os testes. Esperado: falham.
- [ ] **2.3** Implementar.
- [ ] **2.4** Rodar os testes. Esperado: passam.
- [ ] **2.5** Commit `feat(core): platform store`.

### Task 3: Cotações em lote no `RateStore`

**Arquivos:** `AwesomeAPI.swift`, `RateClient.swift`, `RateStore.swift`,
`Tests/CambioCoreTests/Fakes.swift`, `AwesomeAPITests.swift`,
`RateClientTests.swift` e `RateStoreTests.swift`.

**Interfaces produzidas:**
```swift
// AwesomeAPI
public static func latestURL(for pairs: [CurrencyPair]) -> URL            // /json/last/USD-BRL,EUR-BRL
public static func decodeLatest(_ data: Data, pairs: [CurrencyPair]) throws -> [CurrencyPair: Quote] // ignora pares ausentes
// RateFetching (novo requisito)
func latest(_ pairs: [CurrencyPair]) async throws -> [CurrencyPair: Quote]
// RateStore
public init(client:, defaults:, now:, extraPairs: @escaping @MainActor () -> Set<CurrencyPair> = { [] })
public private(set) var quotes: [CurrencyPair: Quote]
public func quote(for pair: CurrencyPair) -> Quote?   // quotes[pair], ou o quote da barra se for o mesmo par
```
**Comportamento do `refresh`:**
- Monta a lista `[pair] + extraPairs()`, sem repetir e com o par da barra
  primeiro.
- Chama `latest(lista)`. Se falhar e a lista tiver mais de um par, tenta de
  novo com `latest([pair])` (ponto de atenção 2).
- O `quote` da barra e o estado "sem conexão" seguem as regras da v1,
  inclusive a da geração mais recente.
- `quotes` é atualizado com o que veio.
- O `FakeClient` implementa `latest(_ pairs:)`, com uma lista de pares
  "inexistentes" que fazem a chamada em lote falhar inteira.

- [ ] **3.1** Escrever os testes:
  - `decodesBatch`: com o JSON real de `USDBRL` mais `EURBRL`, devolve 2
    quotes; com `[USD-BRL, XYZ-BRL]` devolve só o de USD-BRL.
  - `batchURL`: termina em `/json/last/USD-BRL,EUR-BRL`.
  - `clientBatchUsesOneRequest`: os dois pares saem numa única requisição
    registrada.
  - `refreshFetchesExtraPairs`: com extraPairs `{EUR-BRL}`,
    `store.quote(for: EUR-BRL)` não é nil, e `quote(for: .usdBrl) == store.quote`.
  - `badExtraPairFallsBack` (ponto de atenção 2): com extraPairs `{XYZ-BRL}`
    marcado como inexistente no fake:
    - `store.quote` é preenchido e `!store.isOffline`;
    - `quote(for: XYZ-BRL) == nil`.
  - Os testes antigos de `RateStore` continuam passando sem mudança de
    comportamento: o `FakeClient.latest(_ pair:)` passa a delegar para a
    versão em lote.
- [ ] **3.2** Rodar os testes. Esperado: falham.
- [ ] **3.3** Implementar. `RateFetching.latest(_ pair:)` continua existindo
  como extensão que chama a versão em lote, para não quebrar ninguém.
- [ ] **3.4** Rodar `swift test`. Esperado: todos passam.
- [ ] **3.5** Commit `feat(core): fetch platform pairs in one batched request`.

### Task 4: Navegação em pilha e seletor de moedas reutilizável

**Arquivos:** `Views/NavBar.swift` (novo), `Views/PanelView.swift` e
`Views/PickerPage.swift`.

**Interfaces produzidas:**
```swift
struct NavBar: View { init(title: LocalizedStringKey, back: @escaping () -> Void) }   // ou título em String verbatim
enum PanelRoute: Hashable { case picker, calculator, platforms, add, edit(UUID), platformPair(UUID) }
// PanelView: @State path: [PanelRoute]; push(_:), pop(); a página exibida é path.last (ou a principal)
// PickerPage: init(store: RateStore, initial: CurrencyPair, slot: Slot = .base,
//                  onSelect: @escaping (CurrencyPair) -> Void, close: @escaping () -> Void)
```
- Na tela principal, o seletor usa `onSelect = { Task { await store.select($0) } }`,
  com o mesmo comportamento da v1.
- No editor de plataforma, o seletor usa `onSelect` para trocar o par do
  rascunho.
- Toda página entra e sai pela direita. O painel continua com 300 pt de
  largura e com a altura da página principal. Ao perder o foco, a pilha
  esvazia.

- [ ] **4.1** Refatorar sem mudar comportamento.
- [ ] **4.2** Rodar `swift build -c release`. Esperado: sem avisos.
  `swift test` continua verde.
- [ ] **4.3** Rodar `make screenshots`. Esperado: as imagens da v1 ficam
  idênticas visualmente (main e picker, claro e escuro).
- [ ] **4.4** Commit `refactor(app): page stack navigation and reusable picker`.

### Task 5: Interface das plataformas

**Arquivos:** `Views/Platforms/*.swift`, `Views/MainPage.swift`,
`CambioApp.swift`, `Snapshot.swift` e os dois `Localizable.strings`.

**Interfaces consumidas:** `Platform`, `Payout`, `DecimalInput`,
`PlatformStore` e `RateStore.quote(for:)`.

**Telas** (portar da prévia, com os mesmos valores visuais):
- **`PlatformBadge`:**
  - quadrado com cantos contínuos e raio 0,3 × tamanho;
  - gradiente da `PlatformColor` e borda branca de 0,18;
  - a inicial em `.rounded` bold, 0,58 × tamanho.
- **`ReceivingSection`:**
  - cabeçalho "RECEIVING VIA" e o link "Simulate ›";
  - uma linha por plataforma: selo 24, nome, método, e à direita
    `RateFormat.price(Payout.platformRate…)` com 2 casas e
    `−{costPercent}%`;
  - plataforma sem cotação para o seu par mostra "—".
  - Sem plataformas, `MainPage` mostra no lugar a linha "How much will I
    receive? ›".
- **`CalculatorPage`:**
  - cartão "YOU SEND", com o valor em `.rounded` 26 pt e `TextField` (texto
    estático no snapshot) lido por `DecimalInput`;
  - os atalhos;
  - "YOU RECEIVE": a linha do comercial como referência, e as plataformas
    ordenadas por `receive`, cada uma com a perda;
  - a nota "Estimate based on the live commercial rate and each platform's
    fees.";
  - o rodapé "Edit platforms ›";
  - o seletor de moeda de origem só aparece se `baseCurrencies.count > 1`;
  - o valor é salvo em `calculatorAmount`.
- **`PlatformsPage`:** a lista e "Add platform".
- **`AddPlatformPage`:**
  - os modelos `.deelPix` e `.higlobePix`, cada um com a sua descrição, e
    "Custom";
  - a nota "Templates measured in Nov 2026 from real withdrawals. Fees
    change: check your account.";
  - ao escolher, adiciona com `instantiated()`; a personalizada usa a próxima
    cor da paleta e abre o editor.
- **`EditPlatformPage`:**
  - campos de nome, método, moedas (abre o seletor), taxa %, taxa fixa
    (com o código da moeda de origem) e spread %;
  - salva ao sair do campo, só se `isValid`.
  - O bloco "Adjust from the platform's current rate" tem um campo, um
    resultado no formato "spread X% · commercial now Y" e o botão "Apply",
    desabilitado quando `Payout.spread` dá `nil`. Antes de calcular,
    `refreshIfStale(olderThan: 60)`.
  - "Remove platform": o primeiro clique troca o texto para "Confirm
    removal", e o segundo remove e volta.
- **`CambioApp`:**
  - cria o `PlatformStore` e passa `extraPairs: { platforms.pairs }` ao
    `RateStore`;
  - depois de `add`, `update` ou `remove`, chama `store.refresh()`.
- **`Snapshot`:**
  - usa um `PlatformStore` em memória com Deel e Higlobe;
  - gera 8 PNGs: main, calculator, platforms e edit, cada um claro e escuro;
  - todas as views AppKit (`TextField`, `ScrollView`) têm alternativa
    estática quando `isSnapshot`.

**Textos novos** (EN → pt-BR):

| EN | pt-BR |
|---|---|
| RECEIVING VIA | RECEBENDO VIA |
| Simulate | Simular |
| How much will I receive? | Quanto vou receber? |
| How much I receive | Quanto recebo |
| YOU SEND | VOCÊ ENVIA |
| YOU RECEIVE | VOCÊ RECEBE |
| Commercial | Comercial |
| reference | referência |
| %@ per %@ | %@ por %@ |
| Estimate based on the live commercial rate and each platform's fees. | Estimativa com a cotação comercial de agora e as taxas de cada plataforma. |
| Edit platforms | Editar plataformas |
| Platforms | Plataformas |
| How money reaches your account. Cambio applies each one's fees to the live rate. | Como o dinheiro chega na sua conta. O Cambio aplica as taxas de cada uma sobre a cotação ao vivo. |
| Add platform | Adicionar plataforma |
| Start from a template and adjust it with your account's real rate. | Comece por um modelo e ajuste com a cotação real da sua conta. |
| Custom | Personalizada |
| You set the name, fees and spread | Você define nome, taxas e spread |
| Templates measured in Nov 2026 from real withdrawals. Fees change: check your account. | Modelos medidos em nov/2026 com saques reais. Taxas mudam: confira na sua conta. |
| Name | Nome |
| Method | Método |
| Currencies | Moedas |
| Fee on amount | Taxa sobre o valor |
| Fixed fee | Taxa fixa |
| Exchange spread | Spread no câmbio |
| Adjust from the platform's current rate | Ajustar pela cotação de agora |
| Type the rate %@ is showing. Cambio compares it with this minute's commercial rate. | Digite o câmbio que a %@ está mostrando. O Cambio compara com o comercial deste minuto. |
| Apply | Aplicar |
| spread %@ · commercial now %@ | spread %@ · comercial agora %@ |
| Remove platform | Remover plataforma |
| Confirm removal | Confirmar remoção |
| fee %@ | taxa %@ |
| rate −%@ | câmbio −%@ |

- [ ] **5.1** Implementar as views, a ligação no app, o snapshot e os textos.
- [ ] **5.2** Rodar `swift build -c release`. Esperado: sem avisos.
  `swift test` continua verde.
- [ ] **5.3** Rodar `make screenshots`. Esperado:
  - as novas imagens em `docs/screenshots/{en,pt-BR}` batem com a prévia
    aprovada;
  - pt-BR mostra "Recebendo via", "Quanto recebo" etc.
- [ ] **5.4** Rodar `make install`. Esperado: o app abre e a barra mostra a
  cotação.
- [ ] **5.5** Commit `feat(app): receiving platforms and payout calculator`.

### Task 6: Documentação e versão

**Arquivos:** `README.md`, `README.pt-BR.md` e `docs/screenshots/**`.

- [ ] **6.1** No README, acrescentar a seção "How much will I receive?"
  ("Quanto vou receber?" no pt-BR) com:
  - um screenshot da aba;
  - a fórmula;
  - os modelos e a data em que foram medidos;
  - o ajuste pela cotação;
  - o aviso de que os valores são estimativas e as taxas mudam.

  Também atualizar a lista de funcionalidades.
- [ ] **6.2** Rodar `make test app`. Esperado: tudo verde.
- [ ] **6.3** Commit `docs: platforms section and screenshots`, incluindo
  `docs/design-platforms.md` e este plano.

---

## Fora deste plano

- O push e a tag `v1.1.0` ficam com o autor
  (`make zip VERSION=1.1.0` é feito pelo workflow).
- A rota Deel → Higlobe, o saldo e o histórico.
