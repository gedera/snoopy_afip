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

El código nuevo debe venir con tests. Specs actuales: `spec/snoopy_afip/bill_spec.rb`, `spec/snoopy_afip/authorizer_spec.rb`. `spec/spec_helper.rb` requiere una variable de entorno `CUIT` (usar valores de prueba, nunca CUIT/credenciales reales).

## 7. Releases

Usar la skill `/gem-release` (declarada en `skills.yml`) para publicar versiones. La versión vive en `lib/snoopy_afip/version.rb` (`Snoopy::VERSION`).

No hay GitHub Action de release en el repo (no existe `.github/workflows/`). No documentar un pipeline automático que no esté presente.

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
