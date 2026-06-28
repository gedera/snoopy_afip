# Dependencias consumidas — AFIP (WSAA + WSFE)
> meta: artefacto · RFC-018 · generado arch-structure · enriquecido arch-enrich · anclado a 7813cf2 · cobertura: subset SOAP invocado; §c 1/1 · §e 1/1

Entrada de **familia** (RFC-018 §4 r2): ambos servicios externos se invocan por el mismo cliente base `Snoopy::Client` (wrapper de `Savon.client`). Difieren en WSDL, headers y operaciones.

## 2.a Identidad

| campo | valor |
|---|---|
| proveedor / servicio | AFIP (Argentina) — Facturación Electrónica |
| sub-tipo | **externo** |
| transporte | SOAP sobre HTTP/HTTPS |
| cliente nuestro | `Snoopy::Client` (`lib/snoopy_afip/client.rb`) sobre `savon` |
| auth | WSAA: firma CMS/PKCS7 (cert + pkey) → `token`/`sign`. WSFE: `Auth = {Token, Sign, Cuit}` + mTLS (`ssl_cert_file`/`ssl_cert_key_file`) |
| ancla | doc oficial AFIP — ver §5 |

### Miembros de la familia

| miembro | WSDL (config) | cliente | particularidades |
|---|---|---|---|
| **WSAA** (autenticación) | `Snoopy.auth_url` | `AuthenticationAdapter#client_configuration` | `ssl_version`, `pretty_print_xml`; sin headers extra |
| **WSFE** (facturación electrónica v1) | `Snoopy.service_url` | `AuthorizeAdapter#client_configuration` | headers `Accept-Encoding`/`Connection`; namespace `http://ar.gov.afip.dif.FEV1/`; mTLS con `cert`/`pkey`; `read_timeout`/`open_timeout` |

## 2.b Operaciones consumidas (subset usado)

| servicio | operación SOAP | destino (código) | qué mandamos / esperamos |
|---|---|---|---|
| WSAA | `:login_cms` | `AuthenticationAdapter#authenticate!` | enviamos CMS firmado (TRA `loginTicketRequest`, service=`wsfe`); esperamos `loginTicketResponse` con `credentials.token`/`.sign` + `header.expirationTime` |
| WSFE | `:fecae_solicitar` | `AuthorizeAdapter#authorize!` | enviamos `Auth` + `FeCAEReq` (cabecera + detalle: tipo, punto venta, importes, IVA, doc, fechas); esperamos `FECAEDetResponse` con `cae`, `cae_fch_vto`, `resultado`, `cbte_desde` + `errors`/`events`/`observaciones` |
| WSFE | `:fe_comp_ultimo_autorizado` | `AuthorizeAdapter#set_bill_number!` | enviamos `Auth` + `PtoVta` + `CbteTipo`; esperamos `cbte_nro` (último autorizado) → `+1` |
| WSFE | `:fe_comp_consultar` | `AuthorizeAdapter#invoice_informed?` | enviamos `Auth` + `FeCompConsReq` (tipo, nro, punto venta); esperamos `result_get` con estado del comprobante |

## 2.c Semántica de retry / idempotencia

- **La gema NO reintenta**: `Client#call` envuelve la llamada en `Timeout` y al fallar levanta `ServerTimeout`/`ClientError` — el retry queda a cargo del host.
- **`authorize!` (`fecae_solicitar`) NO es idempotente por sí solo**: reenviar el mismo `FeCAEReq` puede generar un comprobante nuevo. La idempotencia se logra usando `set_bill_number!` (lee el último autorizado) o `invoice_informed?` (`fe_comp_consultar`) para verificar antes de reintentar. Reintentar a ciegas tras timeout es **inseguro**: el comprobante pudo haberse autorizado del lado de AFIP. `inferred` — confirmar política con AFIP.
- **`set_bill_number!` / `invoice_informed?` (lecturas) son idempotentes**: reintento seguro.

## 2.d Errores del proveedor → mapeo nuestro

| condición del proveedor | excepción nuestra (ver `docs/errors/`) |
|---|---|
| `Timeout::Error` (corte por `Timeout::timeout(Snoopy.open_timeout)`) | `Snoopy::Exception::ServerTimeout` |
| cualquier otro fallo de transporte/SOAP (`rescue => e`) | `Snoopy::Exception::ClientError` (con `e.message`) |
| errores de negocio AFIP (`FeCAEReq` rechazado, etc.) | **no se levantan**: se parsean a `afip_errors`/`afip_events`/`afip_observations` (code→msg) y el flujo sigue |
| fallo de parseo de la respuesta AFIP | excepciones `Snoopy::Exception::AuthorizeAdapter::*Parser` (ver `docs/errors/`) |

Códigos de error documentados por AFIP para WSAA (`coe.notAuthorized`, `cms.*`, `xml.*`, `wsn.*`, `wsaa.*`) están listados como comentario en `authentication_adapter.rb:17-35` — referencia, no se mapean uno a uno.

## 2.e Degradación

- Si AFIP **no responde** (timeout/red): `Snoopy::Exception::ServerTimeout`/`ClientError` propaga al host. No hay fallback ni cola en la gema — la emisión del comprobante **no procede**. El host decide reintento/cola.
- Si AFIP responde pero **rechaza** (errores de negocio): no hay excepción; `afip_errors` se puebla y `bill.result` queda `R`/`P`. La degradación es "comprobante no aprobado", consultable sin reintentar la red.
- **SLA de AFIP**: no garantizado; ventanas de mantenimiento frecuentes (códigos `wsn.unavailable`/`wsaa.unavailable`). Diseñar el host para tolerar caídas. `inferred`.

## 5. Cobertura y fronteras

- Subset invocado, **no** la API completa de WSFE (la gema usa 4 operaciones de las ~decenas del WS).
- Timeout/SSL: `open_timeout`/`read_timeout` (default 30) y `SNOOPY_SSL_VERSION` parametrizados en el repo → ver `docs/config/`.
- Doc oficial: [Espec. Técnica WSAA 1.2.0](http://www.afip.gov.ar/ws/WSAA/Especificacion_Tecnica_WSAA_1.2.0.pdf) · [Manual desarrollador WSFE](http://www.afip.gob.ar/fe/documentos/manual_desarrollador_COMPG_v2_9.pdf).
- WSDLs: WSAA homo `wsaahomo.afip.gov.ar` / prod `wsaa.afip.gov.ar`; WSFE homo `wswhomo.afip.gov.ar` / prod `servicios1.afip.gov.ar`.
