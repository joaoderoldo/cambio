# Cambio: plano de implementação

**Objetivo:** app de barra de menu para macOS que mostra a cotação de um par de
moedas configurável, atualizada sozinha, open source e fácil de instalar.

**Arquitetura:** um Swift Package com três alvos.
- `CambioCore`: biblioteca só com Foundation e Observation (modelos, API,
  formatação, estado). É ela que é testada.
- `Cambio`: executável SwiftUI. Usa `MenuBarExtra` no estilo `.window`.
- `CambioCoreTests`: testes com Swift Testing.

Um script de build monta o `Cambio.app` (binário universal, assinatura ad-hoc),
e um Makefile amarra os comandos.

**Stack:** Swift 6, SwiftUI, Swift Charts, Observation, ServiceManagement,
Swift Testing. Nenhuma dependência de terceiros.

**Design:** `docs/design.md`, aprovado em 2026-11-17. A referência visual
aprovada é a prévia v2:
- código: uma prévia descartável, fora do repositório
- imagens: uma prévia descartável, fora do repositório

Os valores visuais exatos (fontes, tamanhos, paddings, molas, recorte das
bandeiras `2.2 / 0.08 / 0.06`) vêm de lá. A lógica da prévia **não** é
reaproveitada: ela é reescrita com testes.

## Restrições globais

- macOS 14.0+ (`LSMinimumSystemVersion` 14.0). `swift-tools-version: 6.0`,
  modo de linguagem Swift 6.
- Nenhuma dependência de terceiros.
- Dados de `https://economia.awesomeapi.com.br`, sem chave de API.
- Atualização:
  - a cada 60 s;
  - ao acordar o Mac;
  - ao abrir o painel, se o último dado tiver mais de 15 s.
- Gráfico de 30 dias (`/json/daily/{par}/30`).
- Par padrão `USD-BRL`.
- Interface em inglês (base) e pt-BR, seguindo o idioma do sistema. As chaves
  de tradução são o texto em inglês.
- Nenhuma rede além da AwesomeAPI. Sem analytics, sem rastreamento.
- Binário universal (arm64 + x86_64), assinatura ad-hoc, licença MIT.
- `CFBundleIdentifier` = `app.cambio.Cambio`.
- Commits locais no padrão Conventional Commits, sem trailers. Nada de push.

## Pontos de atenção na revisão

1. **Sem internet na primeira abertura, e sem cache.** A barra mostra
   `USD —`, o painel mostra "Sem conexão" e o app se recupera sozinho no
   próximo ciclo. Teste na Task 4.
2. **O par salvo deixou de existir na API.** O app volta para `USD-BRL` assim
   que o catálogo carrega. Teste na Task 4.
3. **Valores muito pequenos ou muito grandes** (JPY→BRL 0,0384;
   BTC→BRL 512.345). As casas decimais mudam conforme a faixa e a barra não
   fica larga. Teste na Task 3.
4. **O Mac dormiu por horas.** Ao acordar, atualiza na hora em vez de esperar
   60 s, e o ciclo de atualização não se duplica. Testes na Task 4.
5. **A API devolve erro, HTML ou 429.** Isso conta como "sem conexão", o último
   valor é mantido e nada quebra. Testes nas Tasks 2 e 4.

---

## Estrutura de arquivos

```
cambio/
  Package.swift
  Sources/CambioCore/
    CurrencyPair.swift      # par de moedas (USD-BRL)
    Quote.swift             # Quote, DailyPoint
    AwesomeAPI.swift        # URLs e decodificação
    Catalog.swift           # pares válidos, nomes, busca
    RateFormat.swift        # formatação de números, barra e preço
    CurrencyArt.swift       # bandeira ou selo de cada moeda
    RateClient.swift        # protocolo RateFetching + AwesomeAPIClient
    RateStore.swift         # estado observável, persistência, ciclo
  Sources/Cambio/
    Main.swift              # @main: app ou --snapshot
    CambioApp.swift         # MenuBarExtra + eventos do sistema
    LaunchAtLogin.swift     # SMAppService.mainApp
    Snapshot.swift          # gera docs/screenshots/*.png
    Views/BarLabel.swift
    Views/PanelView.swift   # alterna as páginas com mola
    Views/MainPage.swift
    Views/PickerPage.swift
    Views/RateChart.swift
    Views/Components.swift  # CurrencyBadge, PairBadge, ChangeBadge, RowStyle, IconButtonStyle, MiniSwitch
  Tests/CambioCoreTests/*.swift
  Resources/
    Info.plist              # com __VERSION__
    AppIcon.icns
    en.lproj/Localizable.strings
    pt-BR.lproj/Localizable.strings
  scripts/build-app.sh
  scripts/make-icon.swift
  Makefile
  .github/workflows/ci.yml
  .github/workflows/release.yml
  README.md, README.pt-BR.md, LICENSE, .gitignore
  docs/design.md, docs/implementation-plan.md, docs/screenshots/
```

---

### Task 1: Esqueleto do pacote e `CurrencyPair`

**Arquivos:** `Package.swift`, `.gitignore`, `LICENSE`,
`Sources/CambioCore/CurrencyPair.swift`, `Sources/Cambio/Main.swift`
(placeholder que só imprime a versão), `Tests/CambioCoreTests/CurrencyPairTests.swift`.

**Interfaces produzidas:**
```swift
public struct CurrencyPair: Hashable, Codable, Sendable {
    public let base: String, quote: String
    public init(base: String, quote: String)
    public init?(id: String)            // "USD-BRL"; nil se não houver exatamente 2 partes não vazias
    public var id: String               // "USD-BRL"
    public var responseKey: String      // "USDBRL" (chave no JSON de /json/last)
    public var swapped: CurrencyPair
    public static let usdBrl: CurrencyPair
}
```

- [ ] **1.1** `git init -b main` em `cambio/`. Criar:
  - `.gitignore` com `.build/`, `build/`, `.swiftpm/` e `.DS_Store`;
  - `LICENSE` MIT ("Copyright (c) 2026 João Deroldo");
  - `Package.swift` com os 3 alvos, `platforms: [.macOS(.v14)]`, em que
    `Cambio` depende de `CambioCore`.
- [ ] **1.2** Escrever os testes:
  - `parsesId`: `CurrencyPair(id: "USD-BRL")` tem base `USD` e quote `BRL`.
  - `parsesNonIsoQuote`: `CurrencyPair(id: "USD-BRLPTAX")?.quote == "BRLPTAX"`.
  - `rejectsMalformed`: `"USDBRL"`, `"USD-"`, `"-BRL"`, `"A-B-C"` e `""` dão `nil`.
  - `responseKey`: `.usdBrl.responseKey == "USDBRL"`.
  - `swapped`: `.usdBrl.swapped.id == "BRL-USD"`.
  - `codableRoundTrip`: codifica e decodifica, e o resultado é igual ao original.
- [ ] **1.3** Rodar `swift test`. Esperado: falha de compilação (o tipo não existe).
- [ ] **1.4** Implementar `CurrencyPair`.
- [ ] **1.5** Rodar `swift test`. Esperado: todos passam. `swift build` também compila.
- [ ] **1.6** Commit `chore: scaffold swift package` e `feat(core): add CurrencyPair`
  (podem ser um commit só).

### Task 2: Modelos e decodificação da AwesomeAPI

**Arquivos:** `Sources/CambioCore/Quote.swift`, `Sources/CambioCore/AwesomeAPI.swift`,
`Tests/CambioCoreTests/AwesomeAPITests.swift`.

**Interfaces produzidas:**
```swift
public struct Quote: Codable, Equatable, Sendable {
    public let pair: CurrencyPair
    public let bid: Double, high: Double, low: Double
    public let changePercent: Double
    public let timestamp: Date
}
public struct DailyPoint: Codable, Equatable, Sendable, Identifiable {
    public let date: Date, value: Double
    public var id: Date { date }
}
public enum AwesomeAPI {
    public static let host: URL                                        // https://economia.awesomeapi.com.br
    public static func latestURL(for: CurrencyPair) -> URL             // /json/last/USD-BRL
    public static func historyURL(for: CurrencyPair, days: Int) -> URL // /json/daily/USD-BRL/30
    public static let pairsURL: URL                                    // /json/available
    public static let namesURL: URL                                    // /json/available/uniq
    public static func decodeLatest(_ data: Data, pair: CurrencyPair) throws -> Quote
    public static func decodeHistory(_ data: Data) throws -> [DailyPoint] // ordem crescente; ignora itens com número inválido
    public static func decodeCatalog(pairs: Data, names: Data) throws -> Catalog
    public enum Failure: Error, Equatable { case missingPair(String), invalidNumber(String) }
}
```
`Catalog` nasce aqui só com `init(pairs: Set<String>, apiNames: [String: String])`
e as propriedades. As consultas ficam na Task 3.

- [ ] **2.1** Escrever os testes. Os JSON vão inline, copiados das respostas
  reais registradas em 2026-11-17:
  - `latestDecodes`: com o JSON de `USDBRL` (bid "5.776", high "5.8106",
    low "5.7582", pctChange "-0.138311", timestamp "1794925571"), espera
    `bid == 5.776`, `changePercent == -0.138311` e
    `timestamp == Date(timeIntervalSince1970: 1794925571)`.
  - `latestMissingPairThrows`: com o JSON de `USDBRL` e o par `EUR-BRL`,
    lança `.missingPair("EURBRL")`.
  - `latestHtmlThrows`: um corpo `"<html>301 Moved</html>"` lança erro.
  - `historyAscendingAndSkipsBad`: com 3 itens fora de ordem, um deles com
    `bid: "abc"`, devolve 2 pontos em ordem crescente.
  - `urls`: `latestURL(for: .usdBrl).absoluteString` termina em
    `/json/last/USD-BRL`, e `historyURL(..., days: 30)` termina em
    `/json/daily/USD-BRL/30`.
  - `catalogDecodes`: com `{"USD-BRL":"…","USD-BRLT":"…"}` e
    `{"USD":"Dólar Americano","BRL":"Real Brasileiro","BRLT":"Real Brasileiro Turismo"}`,
    `pairs` tem 2 itens e `apiNames["BRLT"]` é o nome de turismo.
- [ ] **2.2** Rodar `swift test --filter AwesomeAPITests`. Esperado: falha.
- [ ] **2.3** Implementar. Os números chegam como `String` e são convertidos com
  `Double(_:)`. `decodeLatest` lê o dicionário `[String: Raw]` pela chave
  `pair.responseKey`.
- [ ] **2.4** Rodar os testes. Esperado: passam.
- [ ] **2.5** Commit `feat(core): decode AwesomeAPI responses`.

### Task 3: Catálogo, formatação e identidade das moedas

**Arquivos:** `Sources/CambioCore/Catalog.swift`, `RateFormat.swift`,
`CurrencyArt.swift`, e `CatalogTests.swift`, `RateFormatTests.swift`,
`CurrencyArtTests.swift` em `Tests/CambioCoreTests/`.

**Interfaces produzidas:**
```swift
extension Catalog {
    public static let empty: Catalog
    public func contains(_ pair: CurrencyPair) -> Bool
    public var bases: [String]                         // únicos, em ordem alfabética
    public func quotes(for base: String) -> [String]   // únicos, em ordem alfabética
    public func displayName(for code: String, locale: Locale = .current) -> String
    public func search(_ codes: [String], query: String, locale: Locale = .current) -> [String]
}
public enum RateFormat {
    public static func fractionDigits(for value: Double, compact: Bool) -> Int
    public static func number(_ value: Double, fractionDigits: Int, locale: Locale = .current) -> String
    public static func barText(base: String, value: Double?, changePercent: Double?, locale: Locale = .current) -> String
    public static func price(_ value: Double, quote: String, locale: Locale = .current) -> String
    public static func percent(_ value: Double, locale: Locale = .current) -> String
}
public enum CurrencyArt {
    public struct Badge: Equatable, Sendable { public let symbol: String; public let red, green, blue: Double }
    public static let popular: [String]   // ["USD","EUR","GBP","BRL","JPY","CAD","AUD","CHF","ARS","BTC"]
    public static func flag(for code: String) -> String?
    public static func badge(for code: String) -> Badge
}
```

**Regras fixadas pelo design e pela prévia:**
- **Casas decimais** (`fractionDigits`): valor ≥ 1000 usa 0 (barra) ou 2
  (painel); valor ≥ 1 usa 2 ou 4; valor < 1 usa 4 ou 6.
- **Seta da barra:** variação > 0 usa `▴`, < 0 usa `▾`, e 0 ou `nil` fica sem
  seta. Sem valor, a barra mostra `"USD —"`.
- **`price`:** formato de moeda com as 3 primeiras letras da quote como código
  ISO (por isso `BRLT` e `BRLPTAX` mostram `R$`), com
  `fractionDigits(compact: false)`.
- **`displayName`:** usa `locale.localizedString(forCurrencyCode:)` quando o
  resultado existe e é diferente do código. Se não, usa `apiNames[code]` e, por
  último, o próprio código.
- **`search`:** compara código e nome sem diferenciar maiúsculas de minúsculas
  e ignorando acentos. Com a busca vazia, devolve a lista sem mudança.
- **`flag`:**
  - cripto e metais não têm bandeira (`nil`);
  - `EUR` vira 🇪🇺;
  - códigos começados em `X` não têm bandeira;
  - nos demais, as 2 primeiras letras viram bandeira se forem uma região de
    `Locale.Region.isoRegions`.
- **`badge`:** usa a tabela da prévia (BTC ₿ laranja, ETH Ξ, LTC Ł, XRP ✕,
  DOGE Ð, BRETT B, XAU Au, XAG e XAGG Ag). Para o resto, um selo cinza 0.55
  com a primeira letra.

- [ ] **3.1** Escrever os testes. As strings formatadas são comparadas depois de
  trocar U+00A0 por espaço comum.
  - `barTextPtBR`: `barText(base:"USD", value:5.776, changePercent:-0.13, locale: pt_BR) == "USD 5,78 ▾"`.
  - `barTextEnUS`: com variação `+0.2` e `en_US`, dá `"USD 5.78 ▴"`.
  - `barTextFlat`: com variação `0`, dá `"USD 5,78"`; com valor `nil`, dá `"USD —"`.
  - `smallAndLargeValues`: JPY `0.0384` dá `"JPY 0,0384"`; BTC `512345.6` dá
    `"BTC 512.346"` (pt_BR).
  - `pricePtBR`: `price(5.776, quote:"BRL")` dá `"R$ 5,7760"`.
    `price(5.776, quote:"BRLPTAX")` começa com `"R$"`.
  - `percent`: `percent(-0.138311, locale: pt_BR) == "0,14%"`.
  - `catalogQueries`: `contains`, `quotes(for:"USD")` contém `"BRL"`, e
    `bases` sem repetição.
  - `displayNames`: em `en_US`, `"USD"` vira `"US Dollar"`; `"BRLT"` vira
    `"Real Brasileiro Turismo"` (vem da API); um código desconhecido `"ZZZ"`
    devolve `"ZZZ"`.
  - `searchIgnoresAccents`: com `pt_BR`, a busca `"dolar"` acha `"USD"`, e a
    busca `"brl"` acha `"BRL"` e `"BRLT"`.
  - `flags`: USD 🇺🇸, EUR 🇪🇺, BRLT 🇧🇷, BRLPTAX 🇧🇷; BTC, XAU e XCD dão `nil`.
  - `badges`: BTC dá `₿`, XAU dá `Au`, ANG dá `A` em cinza.
- [ ] **3.2** Rodar os testes. Esperado: falham.
- [ ] **3.3** Implementar os três arquivos.
- [ ] **3.4** Rodar os testes. Esperado: passam.
- [ ] **3.5** Commit `feat(core): catalog queries, formatting and currency art`.

### Task 4: Cliente HTTP e `RateStore`

**Arquivos:** `Sources/CambioCore/RateClient.swift`, `Sources/CambioCore/RateStore.swift`,
`Tests/CambioCoreTests/RateStoreTests.swift`, `Tests/CambioCoreTests/RateClientTests.swift`.

**Interfaces consumidas:** Tasks 1 a 3.

**Interfaces produzidas:**
```swift
public protocol RateFetching: Sendable {
    func latest(_ pair: CurrencyPair) async throws -> Quote
    func history(_ pair: CurrencyPair, days: Int) async throws -> [DailyPoint]
    func catalog() async throws -> Catalog
}
public struct AwesomeAPIClient: RateFetching {
    public init(load: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) })
}
@MainActor @Observable
public final class RateStore {
    public private(set) var pair: CurrencyPair
    public private(set) var quote: Quote?
    public private(set) var history: [DailyPoint]
    public private(set) var catalog: Catalog
    public private(set) var isOffline: Bool
    public private(set) var isLoading: Bool
    public private(set) var isRunning: Bool
    public init(client: any RateFetching, defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = { Date() })
    public func refresh() async
    public func refreshIfStale(olderThan seconds: TimeInterval) async
    public func loadCatalog() async
    public func select(_ pair: CurrencyPair) async
    public func start(interval: Duration = .seconds(60))
    public func stop()
}
```

**Comportamento:**
- **Cliente:**
  - timeout de 15 s por requisição;
  - uma resposta não-2xx lança `URLError(.badServerResponse)`;
  - `catalog()` busca os dois endpoints em paralelo.
- **Persistência** (chaves `cambio.pair`, `cambio.lastQuote`, `cambio.catalog`
  no `UserDefaults` injetado):
  - no `init`, restaura o par, o último `Quote` (só se for do mesmo par) e o
    catálogo;
  - `refresh` e `loadCatalog` gravam o que buscaram.
- **`refresh`:**
  - Busca `latest` e em seguida `history(…, days: 30)`.
  - Se `latest` falha, mantém o `quote` e marca `isOffline = true`.
  - Se só o `history` falha, mantém o histórico anterior e não marca
    "sem conexão".
- **`refreshIfStale`:** só chama `refresh` se o último fetch bem-sucedido for
  mais antigo que o limite.
- **`loadCatalog`:** se o catálogo vier não vazio e não tiver o par atual,
  chama `select(.usdBrl)`.
- **`select`:**
  - não faz nada se o par for o mesmo;
  - caso contrário, troca o par, limpa `quote` e `history`, persiste e chama
    `refresh`.
- **`start`:**
  - idempotente: se `isRunning`, retorna;
  - abre uma `Task` única que chama `loadCatalog` e depois repete `refresh`
    seguido de `sleep(interval)` até ser cancelada.
- **`stop`:** cancela a `Task` e zera `isRunning`.

- [ ] **4.1** Escrever os testes. Usam um `FakeClient` (actor com respostas
  programáveis e contadores de chamadas), um `UserDefaults(suiteName: UUID)` e
  um relógio injetado.
  - `refreshSuccess`: preenche `quote` e `history`, e `isOffline` fica `false`.
  - `refreshFailureKeepsLastQuote`: um sucesso seguido de uma falha mantém o
    `quote` e põe `isOffline == true`.
  - `firstLaunchOffline`: sem cache e com o cliente falhando, `quote == nil` e
    `isOffline == true` (ponto de atenção 1).
  - `restoresFromDefaults`: um segundo `RateStore` com os mesmos defaults já
    nasce com o par e o `quote` gravados.
  - `ignoresCachedQuoteOfOtherPair`: com o par salvo EUR-BRL e um `lastQuote`
    de USD-BRL, `quote == nil`.
  - `selectSamePairIsNoop`: `latestCalls` não muda.
  - `selectPersistsAndRefreshes`: grava `cambio.pair == "EUR-BRL"` e o `quote`
    passa a ser do novo par.
  - `stalePairFallsBack`: com o par salvo XYZ-BRL e um catálogo sem ele,
    `loadCatalog()` deixa o par em `.usdBrl` (ponto de atenção 2).
  - `refreshIfStale`: com o relógio em t0 depois de um refresh e `olderThan 15`,
    t0+10s não busca e t0+20s busca (ponto de atenção 4).
  - `startIsIdempotent`: `start(); start()` deixa `isRunning == true`, e
    `stop()` deixa `false`. Depois de 200 ms, com intervalo de 1 h,
    `latestCalls == 1`.
  - `clientNon2xxThrows` (`RateClientTests`): um `load` que devolve
    `HTTPURLResponse` 429 lança erro (ponto de atenção 5).
- [ ] **4.2** Rodar os testes. Esperado: falham.
- [ ] **4.3** Implementar `RateClient.swift` e `RateStore.swift`.
- [ ] **4.4** Rodar `swift test`. Esperado: todos passam, sem avisos de
  concorrência do Swift 6.
- [ ] **4.5** Commit `feat(core): rate client and observable store`.

### Task 5: Interface SwiftUI (app de barra de menu)

**Arquivos:** tudo em `Sources/Cambio/`, mais
`Resources/en.lproj/Localizable.strings` e `Resources/pt-BR.lproj/Localizable.strings`.

**Interfaces consumidas:** `RateStore`, `Catalog`, `RateFormat` e `CurrencyArt`.

**Interfaces produzidas:**
- `Main.swift`, `@main enum Main`: com o argumento `--snapshot <dir>`, roda
  `Snapshot.render(to:)` e sai; sem ele, roda `CambioApp.main()`.
- `CambioApp`:
  - cria `RateStore(client: AwesomeAPIClient())` e chama `start()` no `init`;
  - observa `NSWorkspace.didWakeNotification` e chama
    `refreshIfStale(olderThan: 0)`;
  - declara `MenuBarExtra { PanelView } label: { BarLabel }` com
    `.menuBarExtraStyle(.window)`.
- `PanelView`: no `onAppear`, chama `refreshIfStale(olderThan: 15)`.
- `LaunchAtLogin`, `@MainActor @Observable`:
  - `var isEnabled: Bool` lido de `SMAppService.mainApp.status == .enabled`;
  - `func setEnabled(_:)` chama `register` ou `unregister` e relê o status;
  - na primeira abertura começa **desligado**, como manda o sistema.

**Telas** (portar da prévia v2, mantendo os valores visuais):
- **MainPage:**
  - topo com o título de nomes (`displayName(base) → displayName(quote)`),
    o preço em `.rounded` 30 pt com tracking −0,6, o `ChangeBadge` e a linha
    "Today: low … · high …";
  - o `RateChart` (área com gradiente e linha `catmullRom`, 58 pt de altura);
  - a linha "30 days / Updated at …", com "Offline" em laranja quando
    `isOffline`; nesse caso o preço fica com opacidade 0,5;
  - a linha do par com `PairBadge` e o subtítulo "Switch currency";
  - a linha "Open at login" com `MiniSwitch`;
  - o rodapé com "Refresh ⌘R" (ícone que gira 360° em mola) e "Quit ⌘Q".
- **ChangeBadge:** com variação 0, fica cinza e sem seta.
- **PickerPage:**
  - barra de navegação com ‹ e "Currency";
  - os `SlotCard` FROM e TO com o botão ⇄ (habilitado só se o par invertido
    existir);
  - o campo "Search currency or country";
  - as seções "Popular" e "All currencies", ou os resultados da busca;
  - a linha selecionada com ✓ na cor de destaque;
  - "No currency found" quando a lista fica vazia;
  - Esc fecha.
  - Fluxo: ao escolher FROM, o foco passa para TO. Se o par atual seguir
    válido, ele já é aplicado; se não, TO mostra "Choose". Ao escolher TO,
    aplica o par e fecha.
- **PanelView:** a página principal desliza 60 pt e some; o picker entra pela
  direita. Mola `response 0.38, dampingFraction 1`. Largura 300.
- **Snapshot:** gera 4 PNGs (main e picker, claro e escuro, escala 2x) em
  `<dir>`, com o mesmo fundo e a mesma sombra da prévia.

**Textos** (chave em inglês; tradução pt-BR):

| Chave | pt-BR |
|---|---|
| Today: low %@ · high %@ | Hoje: mín %@ · máx %@ |
| today | hoje |
| 30 days | 30 dias |
| Updated at %@ | Atualizado às %@ |
| Offline | Sem conexão |
| Switch currency | Trocar moeda |
| Open at login | Abrir ao iniciar o Mac |
| Refresh | Atualizar |
| Quit | Sair |
| Currency | Moeda |
| FROM | DE |
| TO | PARA |
| Choose | Escolha |
| Destination currency | Moeda de destino |
| Search currency or country | Buscar moeda ou país |
| Popular | Populares |
| All currencies | Todas as moedas |
| No currency found | Nenhuma moeda encontrada |

- [ ] **5.1** Implementar as views e o app.
- [ ] **5.2** Rodar `swift build -c release`. Esperado: compila sem erros nem
  avisos.
- [ ] **5.3** Rodar `.build/release/Cambio --snapshot /tmp/cambio-shots` e abrir os
  4 PNGs. Esperado: iguais às imagens da prévia v2, em inglês (rodando fora do
  `.app`, as chaves aparecem como texto em inglês).
- [ ] **5.4** Commit `feat(app): menu bar UI with currency picker`.

### Task 6: Empacotamento, ícone e instalação

**Arquivos:** `Resources/Info.plist`, `scripts/make-icon.swift`,
`Resources/AppIcon.icns`, `scripts/build-app.sh`, `Makefile`.

**Valores fixos:**
- **Info.plist:**
  - `CFBundleName` e `CFBundleDisplayName` = `Cambio`;
  - `CFBundleExecutable` = `Cambio`;
  - `CFBundleIdentifier` = `app.cambio.Cambio`;
  - `CFBundleIconFile` = `AppIcon`;
  - `CFBundleShortVersionString` = `__VERSION__`, `CFBundleVersion` = `1`;
  - `LSMinimumSystemVersion` = `14.0`, `LSUIElement` = `true`;
  - `CFBundleDevelopmentRegion` = `en`;
  - `LSApplicationCategoryType` = `public.app-category.finance`;
  - `NSHumanReadableCopyright` = `© 2026 João Deroldo. MIT License.`
- **Ícone:** desenhado em código com AppKit e CoreGraphics, sem SF Symbols e
  sem fontes da Apple:
  - quadrado com cantos contínuos na grade de ícones do macOS (arte de 824 px
    dentro da tela de 1024);
  - gradiente verde escuro → verde-azulado;
  - uma linha branca ascendente no estilo do gráfico do painel, com ponto no
    final.

  Gera os tamanhos do `.iconset` e roda `iconutil -c icns`.
- **`build-app.sh [VERSION]`:**
  1. `swift build -c release --arch arm64 --arch x86_64`;
  2. monta `build/Cambio.app`, com o binário em `Contents/MacOS`, o `Info.plist`
     com a versão aplicada, e o `AppIcon.icns` e os `*.lproj` em
     `Contents/Resources`;
  3. assina com `codesign --force --options runtime --sign -`;
  4. confere com `codesign --verify --strict`.
- **Makefile:**
  - `test`;
  - `app` (`VERSION ?= 1.0.0`);
  - `run` (`app` e depois `open`);
  - `install` (encerra o Cambio que estiver aberto, copia com `ditto` para
    `/Applications` e abre);
  - `zip` (`ditto -c -k --keepParent` para `build/Cambio-$(VERSION).zip`);
  - `screenshots` (roda `--snapshot` duas vezes, com
    `-AppleLanguages "(en)" -AppleLocale en_US` para `docs/screenshots/en`, e
    com `-AppleLanguages "(pt-BR)" -AppleLocale pt_BR` para
    `docs/screenshots/pt-BR`);
  - `clean`.

- [ ] **6.1** Gerar o ícone (`swift scripts/make-icon.swift`) e conferir o PNG
  de 1024 px.
- [ ] **6.2** Criar o `Info.plist`, o `build-app.sh` e o `Makefile`.
- [ ] **6.3** Rodar `make app`. Esperado:
  - `lipo -archs build/Cambio.app/Contents/MacOS/Cambio` mostra
    `x86_64 arm64`;
  - `codesign --verify --strict` não reclama.
- [ ] **6.4** Encerrar a prévia ("Cambio Preview") e rodar `make install`.
  Esperado:
  - a barra mostra `USD x,xx ▴/▾`;
  - ao abrir o painel, os dados aparecem em pt-BR;
  - ligar "Abrir ao iniciar o Mac" faz o Cambio aparecer em
    Ajustes → Geral → Itens de Início.
- [ ] **6.5** Rodar `make screenshots`. Esperado: 8 PNGs.
- [ ] **6.6** Commit `build: app bundle, icon and make targets`.

### Task 7: Documentação e CI

**Arquivos:** `README.md`, `README.pt-BR.md`, `.github/workflows/ci.yml`,
`.github/workflows/release.yml`, `docs/screenshots/**`.

- **README (EN), na ordem:**
  1. nome e frase curta;
  2. screenshot claro e escuro;
  3. "Why": recebe do exterior; os apps que existiam eram complexos e pagos;
  4. funcionalidades;
  5. instalação:
     - Releases → descompactar → arrastar para Applications;
     - primeira abertura: System Settings → Privacy & Security → Open Anyway;
     - alternativa: `xattr -dr com.apple.quarantine /Applications/Cambio.app`;
  6. compilar do código: `make install`;
  7. como funciona: AwesomeAPI sem chave, cache de 1 a 5 min, atualização a
     cada 60 s;
  8. privacidade: nenhuma rede além da AwesomeAPI, sem rastreamento;
  9. contribuir: `make test`;
  10. licença.

  O `README.pt-BR.md` é a tradução, com as imagens de
  `docs/screenshots/pt-BR`.
- **`ci.yml`:**
  - roda em `push` e `pull_request` para `main`, em `macos-15`;
  - passos: `swift test` e `make app`.
- **`release.yml`:**
  - roda em tags `v*`, com `permissions: contents: write`, em `macos-15`;
  - passos: `make zip VERSION=${GITHUB_REF_NAME#v}` e depois
    `gh release create "$GITHUB_REF_NAME" build/Cambio-*.zip --generate-notes`,
    com `GH_TOKEN`.

- [ ] **7.1** Escrever os dois READMEs e os dois workflows.
- [ ] **7.2** Validar o YAML (`ruby -ryaml -e 'YAML.load_file(ARGV[0])'` em cada
  arquivo) e rodar `make test app` mais uma vez. Esperado: tudo verde.
- [ ] **7.3** Commit `docs: readme, screenshots and ci workflows`, incluindo
  `docs/design.md` e este plano.

---

## Fora deste plano

- Publicar no GitHub (criar o repositório remoto, fazer push, abrir o primeiro
  release): fica com o autor.
- O post do LinkedIn (PT + EN) é feito depois, com o nome e o link finais.
- "Quanto vou receber" (Deel, Higlobe): é uma próxima feature e vai ter design
  próprio.
