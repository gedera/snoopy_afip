# AGENTS.md — snoopy_afip

Fuente de verdad para reglas, convenciones, estructura, documentación, entorno y arquitectura de esta gema. Leer antes de hacer cambios.

## 1. Identidad

`snoopy_afip` es una gema Ruby que adapta la **Facturación Electrónica de AFIP (Argentina)**. Expone el módulo `Snoopy`.

Resuelve dos servicios SOAP de AFIP (vía `savon`):

- **WSAA** (autenticación): obtiene `token`, `sign` y `expiration_time` a partir de una clave privada y un certificado. Implementado en `Snoopy::AuthenticationAdapter`.
- **WSFE** (autorización de comprobantes electrónicos): autoriza facturas/notas de crédito contra el web service. Implementado en `Snoopy::AuthorizeAdapter`, operando sobre objetos `Snoopy::Bill`.

Verificado en: `snoopy_afip.gemspec` (`summary = "Adaptador AFIP wsfe."`, `description = "Adaptador para Web Service de Facturación Electrónica Argentina (AFIP)"`), `README.md` y `lib/`.

## 2. Convenciones del framework

El repo consume skills del framework de agentes, declaradas en `skills.yml`. Las skills se sincronizan en `.agents/skills/` y traen conocimiento específico de cada herramienta o dependencia.

- Antes de responder o actuar sobre un tema cubierto por una skill, leer la skill correspondiente en `.agents/skills/`.
- Skills declaradas hoy (`skills.yml`): `multi-vendor-feedback`, `yard`, `quality-code`, `gem-release`, `arch-structure`, `arch-compose`, `arch-enrich`, `skill-feedback`, `agent-issue`, `bug-report`, `dev-flow`, `documentation-writer`, `matrix-element`.
- MCPs declarados: `github`, `clickup`.

## 3. Entorno

- Lenguaje: **Ruby**. No hay `.ruby-version` en el repo (no fijar una versión que no esté declarada).
- Dependencias resueltas en `Gemfile.lock`. Dependencia de runtime principal: `savon ~> 2.12.1` (cliente SOAP), declarada en el `.gemspec`.
- Gestión de versiones de Ruby con **chruby** (no rvm, no rbenv).
- **Bundler** para dependencias (`BUNDLED WITH 2.1.4` en `Gemfile.lock`). Instalar con `bundle install`.

## 4. RuboCop

Esta gema **no** tiene `.rubocop.yml` configurado actualmente. La skill `quality-code` está declarada en `skills.yml` para calidad de código. Aplicar las reglas de calidad solo si se incorpora una configuración de RuboCop al repo; en ese caso, correr `bundle exec rubocop -a` antes de commitear.

## 5. YARD

Documentación incremental con la skill `yard`. Medir cobertura de doc con:

```bash
bundle exec yard stats --list-undoc
```

Documentar el código nuevo o modificado.

## 6. Testing

Framework: **RSpec** (verificado en `spec/spec_helper.rb` con `require 'rspec'` y specs `describe`/`it` en `spec/snoopy_afip/`). Correr la suite con:

```bash
bundle exec rspec
```

El código nuevo debe venir con tests. La suite (`spec/snoopy_afip/{bill,authorize_adapter,authentication_adapter,exceptions}_spec.rb`) son unit puros, sin fixtures ni llamadas reales a AFIP; usar placeholders, nunca CUIT/credenciales reales.

**Runtime: la suite corre bajo Ruby 2.7.x** (runtime del consumidor). En Ruby 3.x la gema **no carga** — el stack de savon 2.12 (httpi 2.x) depende de `kconv` y `Rack::Utils::HeaderHash`, removidos en Ruby 3.x / rack 3. Correr en 3.x requiere el upgrade de savon a 2.15+ (ver `docs/test/testing.md`). El `Gemfile.lock` está resuelto para 2.7.

## 7. Releases

La versión vive en `lib/snoopy_afip/version.rb` (`Snoopy::VERSION`).

**Release automatizado por GitHub Actions** (`.github/workflows/release.yml`): publicar = bump de `version.rb` + commit + `git tag vX.Y.Z` + push del tag → el workflow corre `gem build` + `gem push` a RubyGems. Requiere el secret `RUBYGEMS_API_KEY` en el repo. No hace falta `gem push` manual.

**CI** (`.github/workflows/main.yml`): corre `bundle exec rspec` en cada push a master y PR. Hoy en **Ruby 2.7** (stack savon 2.12); subir a 3.x al mergear el upgrade de savon (#19).

## 8. Arquitectura

Derivada de `lib/` (módulo `Snoopy`, autoloads en `lib/snoopy_afip.rb`):

- **`Snoopy`** (`lib/snoopy_afip.rb`): módulo de configuración global vía `attr_accessor` (`cuit`, `sale_point`, `service_url`, `auth_url`, `pkey`, `cert`, `default_document_type`, `default_concept`, `default_currency`, `own_iva_cond`, `open_timeout`, `read_timeout`, `verbose`). `open_timeout`/`read_timeout` por defecto en 30. Expone helpers `auth_hash` y `bill_types`.
- **`Snoopy::Client`** (`client.rb`): envoltorio fino sobre `Savon.client`; `#call` aplica `Timeout` y traduce fallos a `Snoopy::Exception::ServerTimeout` / `Snoopy::Exception::ClientError`.
- **`Snoopy::AuthenticationAdapter`** (`authentication_adapter.rb`): flujo WSAA — genera TRA/CMS y obtiene `token`/`sign`/`expiration_time`. También métodos de generación de clave privada y de solicitud de certificado (`generate_pkey`, `generate_certificate_request_with_ruby`, `..._with_bash`).
- **`Snoopy::AuthorizeAdapter`** (`authorize_adapter.rb`): flujo WSFE — toma un `Bill` más credenciales (`token`/`sign`/`cuit`/`pkey`/`cert`), arma el request, llama al web service y parsea la respuesta en capas independientes (resultado/CAE, `afip_errors`, `afip_events`, `afip_observations`); expone `set_bill_number!` y `authorize!`.
- **`Snoopy::Bill`** (`bill.rb`): modela el comprobante; valida con `valid?`/`errors` y consulta estado de aprobación con `approved?`, `partial_approved?`, `rejected?`.
- **`Snoopy::Constants`** (`constants.rb`) y **`Snoopy::Exception`** (`exceptions.rb`): tablas de dominio (tipos de documento, alícuotas, condiciones de IVA) y jerarquía de excepciones.
- **`lib/snoopy_afip/core_ext/`**: extensiones a `String`, `Hash` y `Float`.

El acoplamiento de las capas de parseo es deliberado (ver README §"No Explota"): un cambio de formato de AFIP en una capa no debe tumbar el parseo de las demás.

## Mapa de conocimiento (cómo leer la doc de este repo)

- **Tu conocimiento = la UNIÓN de este repo + sus asociados.** No termina en el `docs/<capa>/` local: incluye la doc de los servicios/gemas de `skills.yml`. Un flujo o pregunta que cruza repos no vive como doc estática en ninguno — se compone on-demand recorriendo el grafo: seguí las anclas (`docs/consumed/`, `**Canónico:**`) hasta los repos asociados y unificá.
- **Entrá por** [`skill/SKILL.md`](skill/SKILL.md) — índice de agente; resume el contrato y linkea el detalle.
- **Detalle por capa** (`docs/<capa>/`), cobertura declarada:

  | capa | estado |
  |---|---|
  | `docs/interface/` (RFC-004) | presente |
  | `docs/topology/` (RFC-006) | presente |
  | `docs/consumed/` (RFC-018) | presente — AFIP WSAA + WSFE |
  | `docs/errors/` (RFC-020) | presente |
  | `docs/config/` (RFC-012) | presente |
  | `docs/test/` (RFC-013) | presente |
  | `docs/glossary/` (RFC-009) | presente |
  | `docs/behavior/` (RFC-007) | presente |
  | `docs/api/` (RFC-003) | **n/a** — gema SOAP, sin superficie HTTP/CLI/eventos propia |
  | `docs/data/` (RFC-002) | **n/a** — sin base de datos |
  | `docs/events/` (RFC-005) · multi-tenancy (RFC-023) | **n/a** — sin pub/sub ni tenant |

- **Qué consumimos:** [`docs/consumed/afip.md`](docs/consumed/afip.md) (RFC-018) — servicios SOAP externos de AFIP.
- **Navegar una ancla cross-repo:** tomá la key de servicio en `skills.yml` (`services.<dep>.repo`) → ese repo es un checkout hermano local o alcanzable por GitHub MCP. La doc de los asociados ES parte de tu conocimiento accesible. (Hoy las dependencias de esta gema son externas a AFIP, no del fleet.)
