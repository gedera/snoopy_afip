# Configuración runtime — snoopy_afip
> meta: artefacto · RFC-012 · generado arch-structure · enriquecido arch-enrich · anclado a 7813cf2 · cobertura: inventario base 14/14; §f 6/14

## 2.a Hecho verificable

| métrica | valor |
|---|---|
| total opciones | 14 |
| requeridas | 0 (ninguna lanza sin default; faltantes fallan en uso, no en boot) |
| con default | 3 (`open_timeout`, `read_timeout`, `SNOOPY_SSL_VERSION`) |
| derivadas | 0 |
| secretas | 2 (`pkey`, `cert`) |
| origen ENV | 1 (`SNOOPY_SSL_VERSION`) |

Es **gema con configuración pública**: el grueso se setea por código en el host (`Snoopy.<attr> = …`, típicamente un initializer), no por ENV.

## 2.b Inventario base

| nombre | tipo | requerida | default | origen | consumidor | secret? |
|---|---|---|---|---|---|---|
| `Snoopy.cuit` | String | no | `nil` | code-default | `auth_hash`, `AuthorizeAdapter#auth` | no |
| `Snoopy.sale_point` | String | no | `nil` | code-default | host / `Bill#sale_point` | no |
| `Snoopy.service_url` | String (URL/WSDL) | no | `nil` | code-default | `AuthorizeAdapter#client_configuration:186` | no |
| `Snoopy.auth_url` | String (URL/WSDL) | no | `nil` | code-default | `AuthenticationAdapter#client_configuration:115` | no |
| `Snoopy.pkey` | String (path/PEM) | no | `nil` | code-default | `AuthorizeAdapter#client_configuration:193` | **sí** |
| `Snoopy.cert` | String (path/PEM) | no | `nil` | code-default | `AuthorizeAdapter#client_configuration:192` | **sí** |
| `Snoopy.default_document_type` | String | no | `nil` | code-default | `Bill#initialize:30` | no |
| `Snoopy.default_concept` | String | no | `nil` | code-default | `Bill#initialize:22` | no |
| `Snoopy.default_currency` | Symbol | no | `nil` | code-default | `Bill#initialize:24` | no |
| `Snoopy.own_iva_cond` | Symbol | no | `nil` | code-default | host | no |
| `Snoopy.verbose` | String/bool | no | `nil` | code-default | `snoopy_afip.rb:55` (comentado) | no |
| `Snoopy.open_timeout` | Integer | no | `30` | code-default (`lib/snoopy_afip.rb:23`) | `Client#call:10`, `AuthorizeAdapter:191` | no |
| `Snoopy.read_timeout` | Integer | no | `30` | code-default (`lib/snoopy_afip.rb:24`) | `AuthorizeAdapter:190` | no |
| `SNOOPY_SSL_VERSION` | Symbol | no | `:TLSv1` | env (`constants.rb:24`) | `client_configuration` (ambos adapters) | no |

## 2.c Meta-templates

Ninguna (sin patrones `{SERVICE}_{HOST|PORT}` repetidos).

## 2.d Derivaciones simples

- `Snoopy::SNOOPY_SSL_VERSION = (ENV['SNOOPY_SSL_VERSION'] || 'TLSv1').to_sym` — leído **una vez al cargar** `constants.rb` y **congelado** como constante (cambiar el ENV en runtime no tiene efecto).

## 2.e Scheduling

`n/a` (sin sidekiq/queue/cron).

## 2.i Inyecciones al host

- **Monkey-patches globales** (cargados incondicionalmente en `lib/snoopy_afip.rb:7-9`): `core_ext/float.rb`, `core_ext/hash.rb`, `core_ext/string.rb` reabren `Float`/`Hash`/`String`. `Float#round_with_precision`/`round_up_with_precision` y `String#underscore` se redefinen **siempre**; los de `Hash` solo `unless method_defined?`. Sin Railtie/Engine.

## 2.j Inyección a gemas configuradas

`—` (no aplica: no configura gemas de terceros vía bloque).

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| `secret?` de `pkey`/`cert` por contenido (clave privada + certificado), no por nombre | inferred | confirmar manejo (¿path en disco vs PEM inline?) |
| `verbose` consumido solo en línea comentada (`snoopy_afip.rb:55`) | declared | accessor vivo pero sin efecto actual — posible config muerta |

## f. Enriquecimiento semántico

> cobertura: 6/14 vars enriquecidas; ausencia ≠ "no aplica".

### f.1 credenciales (`cuit`, `pkey`, `cert`)

| var | categoría | failure-mode | side-effect | scope-override | business-reason / definición |
|---|---|---|---|---|---|
| `Snoopy.pkey` | infra | runtime-error al firmar CMS (`CmsBuilder`) si falta/inválida | restart (se relee por request al construir cliente) | mutable-singleton | clave privada que firma el CMS de WSAA y el mTLS de WSFE; **secreto** |
| `Snoopy.cert` | infra | runtime-error (`CmsBuilder`) / handshake TLS si inválido | restart | mutable-singleton | certificado emitido por AFIP; identifica al emisor; **secreto** |
| `Snoopy.cuit` | business | request rechazado por AFIP si no coincide con el cert | per-request | mutable-singleton | CUIT del emisor; debe coincidir con el del trámite del certificado |

### f.2 endpoints (`auth_url`, `service_url`)

| var | categoría | failure-mode | side-effect | scope-override | business-reason / definición |
|---|---|---|---|---|---|
| `Snoopy.auth_url` | integration | `ClientError` (WSDL inalcanzable) | restart | mutable-singleton | WSDL de WSAA; **homologación vs producción** se elige acá (riesgo: emitir contra prod por error) |
| `Snoopy.service_url` | integration | `ClientError` | restart | mutable-singleton | WSDL de WSFE; mismo riesgo homo/prod |

### f.3 tuning de red (`open_timeout`, `read_timeout`, `SNOOPY_SSL_VERSION`)

| var | categoría | failure-mode | side-effect | scope-override | business-reason / definición |
|---|---|---|---|---|---|
| `SNOOPY_SSL_VERSION` | tuning | handshake TLS falla si AFIP no soporta la versión | **compile-time-only** (congelado al cargar `constants.rb`) | boot-only | default `:TLSv1` quedó **desactualizado** — AFIP exige TLS ≥1.2; revisar (`inferred`) |

**Ramificadores:** `issuer_iva_cond = :responsable_monotributo` ramifica `alicivas` (monotributo no informa IVA — `authorize_adapter.rb:75`). Es ramificador de payload, no intra-config.

## 4. Cobertura y fronteras

- **Valores reales prohibidos**: solo shape. CUIT/pkey/cert se setean en el host; nunca commitear valores.
- `ENV["CUIT"]` aparece en `spec/spec_helper.rb` pero es **config de test**, no de la gema → ver `docs/test/`.
- Enriquecimiento (`categoría`, `failure-mode`, `side-effect`, `business reason`, threading) → arch-enrich (§f).
