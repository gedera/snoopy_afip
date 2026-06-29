# Test — snoopy_afip
> meta: artefacto · RFC-013 · generado arch-structure · enriquecido arch-enrich · anclado a 7813cf2 (suite reescrita en fix/specs-and-lock) · cobertura: inventario estructural; §e-§h 4/4

## 1. Resumen

Suite RSpec en `spec/`, **reescrita contra la API actual y verde** (`21 examples, 0 failures`) bajo **Ruby 3.x**. Tras el upgrade a savon 2.17 (httpi 4, #19) la gema **requiere Ruby ≥ 3.0** (savon 2.15+/httpi 4 lo exigen) y dejó de soportar Ruby 2.7.

## 2.a Suites, frameworks y niveles

| framework | archivo | propósito | nivel |
|---|---|---|---|
| RSpec | `spec/snoopy_afip/bill_spec.rb` | `Bill`: cbte_type, iva_sum/total, exchange_rate, receiver_iva_condition_id, estado del resultado, `valid?` | unit |
| RSpec | `spec/snoopy_afip/authorize_adapter_spec.rb` | `AuthorizeAdapter`: `auth`, y regresión de rescues de parseo (#10/#16) | unit |
| RSpec | `spec/snoopy_afip/authentication_adapter_spec.rb` | `AuthenticationAdapter`: `build_tra`, credenciales de instancia | unit |
| RSpec | `spec/snoopy_afip/exceptions_spec.rb` | jerarquía `Snoopy::Exception` + paraguas `Error` (regresión #14) | unit |
| RSpec | `spec/spec_helper.rb` | bootstrap + config base de homologación | — |

## 2.b Comando de corrida

```bash
bundle exec rspec    # bajo Ruby >= 3.0
```

No hay CI declarado (sin `.github/workflows/`, `.circleci/`, `bin/ci`, `config/ci.rb`). Corrida solo local. Dev-deps de test: `rspec ~> 3.13`, `activesupport` (gemspec).

## 2.c Fixtures / Factories

- **Sin fixtures en disco.** Los specs son unit puros: construyen `Bill`/adapters con placeholders inline; no requieren `spec/fixtures/pkey`/`cert.crt` ni llamadas reales a AFIP.
- Sin FactoryBot, sin VCR. Las URLs de homologación se setean en `spec_helper.rb` pero ninguna prueba abre conexión (Savon es lazy salvo el build del cliente, que no conecta).
- `Bill#valid?` necesita `blank?`/`present?` → `spec_helper` carga `active_support/core_ext/object/blank`.

## 2.d Configuración de coverage

Ninguna (sin `.simplecov` / `SimpleCov.start`). Sin umbral declarado.

## 2.e Gaps de cobertura

**Cubierto** (unit, sin red): lógica de `Bill` (cálculos, validaciones, mapeos de dominio), jerarquía de excepciones + paraguas, `build_tra`, y el **comportamiento de los rescues de parseo** (no explotan, registran String).

**NO cubierto** (requiere mock de Savon / VCR / homologación real):
- `authorize!` / `set_bill_number!` / `invoice_informed?` — el camino feliz contra WSFE (no se mockea la respuesta SOAP).
- `authenticate!` / `build_cms` — firma CMS con cert/pkey reales.
- `parse_*` con respuestas AFIP **válidas** (solo se testea el path de error).
- `core_ext` (`round_with_precision`, `deep_symbolize_keys`, `underscore`).

## 2.f Contract-assessment

| contrato público | test? |
|---|---|
| operaciones (RFC-003) | n/a (gema sin superficie) |
| dependencias consumidas WSAA/WSFE (RFC-018) | **parcial** — `build_tra` sí; las llamadas SOAP no se ejercitan (sin mock/VCR) |
| errores públicos (RFC-020) | **sí** — jerarquía `Snoopy::Exception::*` + paraguas `Error` + comportamiento de los rescues |

## 2.g Link a incidente

- `exceptions_spec.rb` fija la jerarquía de `ServerTimeout` (regresión de **#14**).
- `authorize_adapter_spec.rb` fija que los rescues de parseo no explotan y registran String (regresión de **#10/#16** — el diseño "No Explota" que nació de un incidente real con cambios de formato de AFIP).

## 2.h PII en fixtures

- Sin fixtures con PII (no hay fixtures en disco). `pkey`/`cert`/`cuit` en specs son placeholders inline (`/tmp/pkey`, `"20111111112"`), nunca material real.

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| La gema requiere Ruby ≥ 3.0 tras el upgrade a savon 2.17 (#19); ya no soporta 2.7 | declared | el consumidor `argentina_invoice_service` (Ruby 2.7.6) debe subir Ruby antes de adoptar la versión nueva |
| El handshake mTLS contra AFIP con httpi 4 NO se validó en tests (solo el build del cliente) | declared | validar WSAA+WSFE contra homologación con certs reales; revisar `SNOOPY_SSL_VERSION` (default `:TLSv1` desactualizado) |

## 4. Cobertura y fronteras

- El contenido detallado de cada test queda en el código.
- Falta cobertura de los caminos felices contra AFIP (necesita mock de Savon o VCR) — próximo incremento.
- La corrida en Ruby 3.x está bloqueada por el stack de dependencias, no por los specs.
