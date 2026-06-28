# Test — snoopy_afip
> meta: artefacto · RFC-013 · generado arch-structure · enriquecido arch-enrich · anclado a 7813cf2 · cobertura: inventario estructural; §e-§h 4/4

## 1. Resumen

Suite RSpec en `spec/`. **Estado crítico**: los specs actuales están **desactualizados respecto al código** — referencian una API que ya no existe (`Snoopy::Bill.header`, `Snoopy::Authorizer`, `Snoopy::NullOrInvalidAttribute`, `@bill.net`, `@bill.authorize`, `Snoopy.default_moneda`) y `spec_helper.rb` hace `require 'snoopy'` (el archivo es `snoopy_afip`). No corren verde contra `lib/` actual.

## 2.a Suites, frameworks y niveles

| framework | subdirectorio | propósito | nivel | tags |
|---|---|---|---|---|
| RSpec | `spec/snoopy_afip/bill_spec.rb` | comportamiento de `Bill` (header, cbte_type, iva_sum, autorización) | unit/integration | — |
| RSpec | `spec/snoopy_afip/authorizer_spec.rb` | lectura de credenciales en init | unit | — |
| RSpec | `spec/spec_helper.rb` | bootstrap + config global de prueba | — | — |

## 2.b Comando de corrida

```bash
bundle exec rspec
```

No hay CI declarado (sin `.github/workflows/`, `.circleci/`, `bin/ci`, `config/ci.rb`). Corrida solo local.

## 2.c Fixtures / Factories

- Fixtures por path en `spec_helper.rb`: `Snoopy.pkey = "spec/fixtures/pkey"`, `Snoopy.cert = "spec/fixtures/cert.crt"`. **El directorio `spec/fixtures/` no está versionado** (no aparece en `git ls-files`) → los specs no tienen sus fixtures.
- Sin FactoryBot; sin `spec/support/` versionado (el `Dir[...support...]` no matchea nada).
- `ENV["CUIT"]` requerida por `spec_helper.rb:16` (usar valor de prueba, nunca CUIT real).
- URLs de **homologación** AFIP (`wsaahomo`/`wswhomo`) cableadas en el helper.

## 2.d Configuración de coverage

Ninguna (sin `.simplecov` / `SimpleCov.start`). Sin umbral declarado.

## 2.e Gaps de cobertura

**Cobertura real efectiva: ~0%.** Los specs no corren contra el código actual (API divergente). Flujos de negocio **sin cobertura ejecutable**:
- Autenticación WSAA (`authenticate!`, `build_cms`/`build_tra`) — no testeado.
- Autorización WSFE (`authorize!`, `build_body_request`) — el spec viejo lo intentaba pero contra API inexistente.
- Parseo en capas de la respuesta AFIP (`parse_*`) — no testeado; es la lógica más frágil (depende del formato de AFIP).
- Validaciones de `Bill#valid?` — el spec viejo no las cubre.
- `core_ext` (round_with_precision, deep_symbolize_keys) — no testeado.

## 2.f Contract-assessment

| contrato público | test? |
|---|---|
| operaciones (RFC-003) | n/a (gema sin superficie) |
| dependencias consumidas WSAA/WSFE (RFC-018) | **no** — sin mocks de Savon ni VCR; ninguna llamada AFIP ejercitada |
| errores públicos (RFC-020) | **no** — jerarquía `Snoopy::Exception::*` sin tests |

Ningún contrato público está cubierto. Riesgo alto: un cambio de formato de AFIP no lo detecta ningún test.

## 2.g Link a incidente

Ninguno declarado. El diseño "No Explota" (parseo en capas, README §) nació de un incidente real (AFIP cambió la estructura de eventos y "explotaba todo") — narrado en el README pero **sin test de regresión** que lo fije.

## 2.h PII en fixtures

- `spec_helper.rb` referencia `spec/fixtures/pkey` y `spec/fixtures/cert.crt` (**no versionados**). Si se agregan, serían **clave privada + certificado AFIP = secretos**: nunca commitear reales; usar material de homologación descartable.
- `ENV["CUIT"]`: usar CUIT de prueba, nunca uno real (es dato identificatorio).
- Sin otros fixtures con PII detectados.

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| Specs no ejecutables contra el código actual (API divergente + `require` roto + fixtures ausentes) | declared | la suite es legacy pre-refactor; decidir reescritura o baja |
| `Gemfile` incluye `ruby-debug` (`require 'ruby-debug'` en helper) | inferred | dep de test posiblemente incompatible con Ruby moderno |

## 4. Cobertura y fronteras

- El contenido detallado de cada test queda en el código.
- Evaluación de gaps/contract/PII → arch-enrich (§e-§h).
- La divergencia specs↔código es el hallazgo dominante de esta capa: bloquea cualquier afirmación de cobertura real.
