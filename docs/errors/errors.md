# Errores / fallos públicos — snoopy_afip
> meta: artefacto · RFC-020 · generado arch-structure · enriquecido arch-enrich · anclado a 7813cf2 · cobertura: jerarquía `Snoopy::Exception::*`; §c 13/13

## 1. Resumen

Gema sin superficie HTTP → no hay códigos de estado (§b n/a). El contrato del unhappy path es la jerarquía de excepciones `Snoopy::Exception::*` que la gema **levanta** hacia el host, más el patrón "no explota": los errores de negocio de AFIP no se levantan, se acumulan en hashes (`afip_errors`/`afip_events`/`afip_observations`) y los fallos de parseo se acumulan en `errors`.

## 2.a Inventario de excepciones públicas

| excepción | jerarquía base | qué la levanta |
|---|---|---|
| `Snoopy::Exception::Exception` | `< ::StandardError` | base de la gema; `initialize(msg, backtrace)` |
| `Snoopy::Exception::ClientError` | `< Exception` | `Client#call` ante cualquier fallo no-timeout de la llamada SOAP |
| `Snoopy::Exception::ServerTimeout` | `< Timeout::Error` | `Client#call` cuando expira `Timeout::timeout(Snoopy.open_timeout)` — **no** hereda de la base de la gema |
| `Snoopy::Exception::AuthenticationAdapter::CmsBuilder` | `< Exception` | `AuthenticationAdapter#build_cms` si falla la firma PKCS7 / lectura de pkey-cert |
| `Snoopy::Exception::AuthorizeAdapter::SetBillNumberParser` | `< Exception` | `#set_bill_number!` ante fallo de parseo de `fe_comp_ultimo_autorizado` |
| `Snoopy::Exception::AuthorizeAdapter::BuildBodyRequest` | `< Exception` | `#build_body_request` si falla armar el `FeCAEReq` |
| `Snoopy::Exception::AuthorizeAdapter::FecaeSolicitarResultParser` | `< Exception` | `#parse_fecae_solicitar_response` (capa resultado/CAE) |
| `Snoopy::Exception::AuthorizeAdapter::FecaeResponseParser` | `< Exception` | `#parse_fecae_solicitar_response` (capa response) — se **acumula** en `errors`, no se raise-a |
| `Snoopy::Exception::AuthorizeAdapter::ObservationParser` | `< Exception` | `#parse_observations` — se acumula en `errors` |
| `Snoopy::Exception::AuthorizeAdapter::ErrorParser` | `< Exception` | `#parse_errors` — se acumula en `errors` |
| `Snoopy::Exception::AuthorizeAdapter::EventsParser` | `< Exception` | `#parse_events` — se acumula en `errors` |
| `Snoopy::Exception::Bill::MissingAttributes` | `< Exception` | validación de presencia (`Bill#valid?`) — mensaje, se acumula en `bill.errors` |
| `Snoopy::Exception::Bill::InvalidValueAttribute` | `< Exception` | validación de valor estándar (currency/iva/doc/concept) — se acumula en `bill.errors` |

## 2.b Códigos HTTP por superficie

`n/a` — la gema no expone superficie HTTP (no hay controllers/routes). El transporte HTTP lo gestiona `savon` internamente.

## 2.c Política por error

| excepción | retriable? | backoff | idempotencia req. | acción |
|---|---|---|---|---|
| `ServerTimeout` | condicional | sí (host) | **sí** — verificar con `invoice_informed?` antes de reintentar `authorize!` | propagate + report |
| `ClientError` | condicional | sí (host) | sí (idem) | propagate + report |
| `AuthenticationAdapter::CmsBuilder` | no | — | — | propagate (config/cert inválido — no reintentable) |
| `AuthorizeAdapter::BuildBodyRequest` | no | — | — | propagate (datos del bill mal formados) |
| `AuthorizeAdapter::SetBillNumberParser` | no | — | — | propagate + report (AFIP cambió formato) |
| `AuthorizeAdapter::FecaeSolicitarResultParser` | no | — | — | propagate + report (capa crítica: revisar `response` cruda) |
| `…FecaeResponseParser` / `…ObservationParser` / `…ErrorParser` / `…EventsParser` | no | — | — | log/acumular en `errors` (no fatal: el CAE ya pudo parsearse) |
| `Bill::MissingAttributes` / `Bill::InvalidValueAttribute` | no | — | — | log en `bill.errors` (validación local, corregir input) |

Notas:
- `report` = candidato a Sentry/exis_ray (observabilidad = otra capa).
- Tras `ServerTimeout`/`ClientError` en `authorize!`, **nunca** reintentar a ciegas: el comprobante pudo haberse emitido en AFIP (ver `docs/consumed/afip.md §c`).
- `inferred`: la criticidad/acción la deduje del diseño "No Explota" + flujo; el humano confirma la política operacional real.

## 2.d Shape del payload de error

No hay payload serializado (no es servicio). Las formas que cruzan la frontera:

- **Excepción Ruby**: `message` + `backtrace` (la base guarda `backtrace` en `attr_accessor`).
- **`bill.errors`**: `Hash` `{ attr_symbol => [String mensajes] }` (validación).
- **`authorize_adapter.errors`**: colección de excepciones de parseo no-fatales.
- **`afip_errors` / `afip_events` / `afip_observations`**: `Hash` `{ code => msg }` con lo devuelto por AFIP.

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| `ServerTimeout < Timeout::Error` (no `< Snoopy::Exception::Exception`) | declared | un `rescue Snoopy::Exception::Exception` **no** atrapa timeouts — confirmar si es intencional |
| `authorize_adapter.rb:182` referencia `Snoopy::Exception::FecompConsultResponseParser` pero la clase definida es `…::AuthorizeAdapter::FecompConsultResponseParser` | declared | el `raise` levantaría `NameError` en ese path — posible bug latente (código existente, no tocar sin decisión) |
| `errors <<` en varios `parse_*` rescue trata `errors` como Array, pero se inicializa `{}` (Hash) | declared | `Hash#<<` no existe → `NoMethodError` en ese rescue — posible bug latente |

## 4. Cobertura y fronteras

- Solo errores **públicos** (cruzan la frontera de la gema). Rescates internos no listados.
- Errores del proveedor AFIP que consumimos → su mapeo en `docs/consumed/afip.md §d`.
- Política de retry/acción → `docs/errors` §c, lo completa arch-enrich.
