# Interfaz — snoopy_afip
> meta: artefacto · RFC-004 · generado arch-structure · anclado a 7813cf2 · cobertura: superficie pública de `lib/snoopy_afip/`

## 1. Resumen

API Ruby pública de la gema. Módulo raíz `Snoopy` (configuración global + helpers) y cuatro clases de dominio: `AuthenticationAdapter` (WSAA), `AuthorizeAdapter` (WSFE), `Bill` (comprobante), `Client` (wrapper Savon). Constantes de dominio en `Snoopy::*` y jerarquía de errores en `Snoopy::Exception::*`.

## 2. Símbolos públicos

| símbolo | tipo | nota |
|---|---|---|
| `Snoopy` | module | raíz; `extend self`; config global vía `attr_accessor` |
| `Snoopy.cuit` `=` | accessor | CUIT del emisor |
| `Snoopy.sale_point` `=` | accessor | punto de venta |
| `Snoopy.service_url` `=` | accessor | WSDL de WSFE |
| `Snoopy.auth_url` `=` | accessor | WSDL de WSAA |
| `Snoopy.pkey` `=` | accessor | path/contenido de clave privada |
| `Snoopy.cert` `=` | accessor | path/contenido de certificado |
| `Snoopy.default_document_type` `=` | accessor | default de `Bill#document_type` |
| `Snoopy.default_concept` `=` | accessor | default de `Bill#concept` |
| `Snoopy.default_currency` `=` | accessor | default de `Bill#currency` |
| `Snoopy.own_iva_cond` `=` | accessor | condición IVA propia |
| `Snoopy.verbose` `=` | accessor | flag de verbosidad (Savon) |
| `Snoopy.open_timeout` `=` | accessor | timeout de apertura; default `30` |
| `Snoopy.read_timeout` `=` | accessor | timeout de lectura; default `30` |
| `Snoopy.auth_hash` | method | `{"Token"=>…, "Sign"=>…, "Cuit"=>…}` — ver §3 |
| `Snoopy.bill_types` | method | array `[etiqueta, código]` de tipos habilitados |
| `Snoopy::Client` | class | wrapper de `Savon.client` |
| `Snoopy::Client#initialize(attrs)` | method | `attrs` → opciones Savon |
| `Snoopy::Client#call(service, args={})` | method | invoca SOAP con `Timeout`; devuelve `.body`; traduce fallos a `ServerTimeout`/`ClientError` |
| `Snoopy::Client#savon` `=` | accessor | cliente Savon subyacente |
| `Snoopy::AuthenticationAdapter` | class | flujo WSAA |
| `…#initialize(attrs={})` | method | `attrs[:pkey]`, `attrs[:cert]` |
| `…#authenticate!` | method | invoca `:login_cms`; devuelve hash con `:token`, `:sign`, `:expiration_time` |
| `…#build_tra` | method | arma el TRA (XML) para `wsfe` |
| `…#build_cms` | method | firma el TRA en PKCS7 → CMS base64 |
| `….generate_pkey(leng=8192)` | class method | genera clave privada RSA PEM |
| `….generate_certificate_request_with_ruby(pkey, subj_o, subj_cn, subj_cuit)` | class method | CSR vía OpenSSL Ruby |
| `….generate_certificate_request_with_bash(pkey, subj_o, subj_cn, subj_cuit)` | class method | CSR vía `openssl req` (shell) |
| `Snoopy::AuthorizeAdapter` | class | flujo WSFE |
| `…#initialize(attrs)` | method | `:bill, :cuit, :sign, :pkey, :cert, :token` |
| `…#authorize!` | method | invoca `:fecae_solicitar`; setea CAE/result en `bill`; devuelve bool |
| `…#set_bill_number!` | method | invoca `:fe_comp_ultimo_autorizado`; setea `bill.number` |
| `…#invoice_informed?` | method | invoca `:fe_comp_consultar`; devuelve bool |
| `…#auth` | method | `{"Token"=>…, "Sign"=>…, "Cuit"=>…}` de la instancia |
| `…#errors` `=` | accessor | errores internos de parseo (hash de excepciones) |
| `…#afip_errors` `=` | accessor | errores devueltos por AFIP (`code=>msg`) |
| `…#afip_events` `=` | accessor | eventos devueltos por AFIP |
| `…#afip_observations` `=` | accessor | observaciones devueltas por AFIP |
| `…#request` `=` / `#response` `=` | accessor | payload enviado / respuesta cruda |
| `Snoopy::Bill` | class | modela el comprobante |
| `…#initialize(attrs={})` | method | ver §4 README para `attrs` |
| `…#valid?` | method | corre validaciones; puebla `#errors` |
| `…#errors` `=` | accessor | hash `attr => [mensajes]` |
| `…#total` | method | neto + IVA, redondeado 2 |
| `…#iva_sum` | method | suma de `amount` de `alicivas` |
| `…#cbte_type` | method | código de comprobante según `receiver_iva_cond` |
| `…#cbte_asoc_type` | method | código del comprobante asociado |
| `…#receiver_iva_condition_id` | method | id de condición IVA del receptor (RG 5616) |
| `…#exchange_rate` | method | `1` si `:peso`; resto sin implementar (ver §3) |
| `…#approved?` / `#rejected?` / `#partial_approved?` | method | estado del resultado AFIP (`A`/`R`/`P`) |
| `…#to_h` / `#to_hash` | method | volcado de instance vars |
| `Snoopy::Bill::ATTRIBUTES` | const | lista de `attr_accessor` del comprobante |
| `Snoopy::Bill::TAX_ATTRIBUTES` | const | `[:id, :amount, :taxeable_base]` |
| `Snoopy::Bill::ATTRIBUTES_PRECENSE` | const | atributos requeridos en validación |
| `Snoopy::CBTE_TYPE` `Snoopy::BILL_TYPE` `Snoopy::CONCEPTS` `Snoopy::DOCUMENTS` `Snoopy::CURRENCY` `Snoopy::ALIC_IVA` `Snoopy::IVA_COND` `Snoopy::IVA_COND_RECEIVER` | const | tablas de dominio (ver `docs/data/` n/a → enriquecer en glosario) |
| `Snoopy::RESPONSABLE_INSCRIPTO` `…_MONOTRIBUTO` `CONSUMIDOR_FINAL` `IVA_SUJETO_EXENTO` `IVA_NO_ALCANZADO` | const | símbolos de condición IVA |
| `Snoopy::SNOOPY_SSL_VERSION` | const | versión TLS (de `ENV['SNOOPY_SSL_VERSION']`, default `:TLSv1`) — ver `docs/config/` |
| `Snoopy::Exception::*` | module/class | jerarquía de errores — ver `docs/errors/` |
| `String#underscore` `Hash#symbolize_keys[!]` `Hash#deep_symbolize_keys` `Hash#underscore_keys[!]` `Float#round_with_precision` `Float#round_up_with_precision` | core_ext | **monkey-patches globales** sobre `String`/`Hash`/`Float` — contaminan el host (ver §4) |

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| `Bill#exchange_rate` solo resuelve `:peso` (`return 1`); el resto del método está comentado → devuelve `nil` para moneda extranjera | declared | confirmar si es intencional o feature incompleta |
| `Snoopy.auth_hash` usa `Snoopy::TOKEN` / `Snoopy::SIGN` (constantes **no definidas** en el código leído) | declared | `auth_hash` levantaría `NameError`; `AuthorizeAdapter#auth` es la vía viva — confirmar si `auth_hash` es legacy muerto |
| `core_ext` define métodos solo `unless method_defined?` (Hash/String) pero `Float` y `String#underscore` se redefinen siempre | declared | colisión potencial con ActiveSupport en hosts Rails |

## 4. Cobertura y fronteras

- **Significado de negocio** de constantes/atributos → fuera de alcance (va a `docs/glossary/`, arch-enrich).
- **Errores** detallados → `docs/errors/` (RFC-020).
- **Config runtime** (`ENV`, accessors) → `docs/config/` (RFC-012).
- **core_ext globales**: la gema parchea `String`/`Hash`/`Float` del host — superficie pública de facto aunque no sea el API previsto; el impacto (colisión con ActiveSupport) es concern de comportamiento → arch-enrich.
- `Snoopy::Exception::ServerTimeout < Timeout::Error` (no hereda de `Snoopy::Exception::Exception`) — detalle en `docs/errors/`.
