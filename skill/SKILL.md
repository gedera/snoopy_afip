---
name: snoopy-afip
description: >
  Gema Ruby `snoopy_afip` — adaptador de Facturación Electrónica de AFIP
  (Argentina). Resuelve los servicios SOAP WSAA (autenticación: token/sign a
  partir de cert+pkey) y WSFE (autorización de comprobantes: devuelve CAE) vía
  `savon`. Activá esta skill cuando trabajes con emisión de facturas/notas de
  crédito electrónicas argentinas, autenticación contra AFIP, el módulo
  `Snoopy`, o las clases `AuthenticationAdapter` / `AuthorizeAdapter` / `Bill`.
triggers:
  - "facturación electrónica AFIP"
  - "emitir factura electrónica argentina"
  - "autenticar contra WSAA"
  - "autorizar comprobante WSFE"
  - "obtener CAE de AFIP"
  - "usar la gema snoopy_afip"
  - "Snoopy::AuthorizeAdapter / Snoopy::Bill"
---

# snoopy_afip — skill de agente

Contrato resumido de la gema. El detalle vive en `docs/<capa>/` (anclado a `4.3.0` / commit `7813cf2`); esta skill indexa y resume.

## Qué es / cuándo usar

Adaptador de la Facturación Electrónica de AFIP. Úsala para autenticar (WSAA) y autorizar comprobantes (WSFE) desde Ruby. Se configura en el host vía `Snoopy.<attr> = …` y se opera con tres clases. No corre como proceso propio: es librería embebida.

## Contrato resumido (piso mínimo)

**Flujo típico** (autenticar → numerar → autorizar):

```ruby
auth = Snoopy::AuthenticationAdapter.new(pkey: pkey, cert: cert)
creds = auth.authenticate!                      # {token, sign, expiration_time} (12h)

bill = Snoopy::Bill.new(cuit:, sale_point:, concept:, document_type:, document_num:,
                        issuer_iva_cond:, receiver_iva_cond:, receiver_iva_condition:,
                        total_net:, alicivas:)   # alicivas: [{id:, amount:, taxeable_base:}]
adapter = Snoopy::AuthorizeAdapter.new(bill:, pkey:, cert:, cuit:,
                                       token: creds[:token], sign: creds[:sign])
adapter.set_bill_number!                         # último autorizado + 1
adapter.authorize!                               # setea bill.cae / bill.result
```

**Símbolos clave:** `Snoopy` (config global), `Snoopy::AuthenticationAdapter` (WSAA), `Snoopy::AuthorizeAdapter` (WSFE), `Snoopy::Bill` (comprobante), `Snoopy::Client` (wrapper Savon). Tablas de dominio: `Snoopy::BILL_TYPE`, `ALIC_IVA`, `IVA_COND_RECEIVER`, `DOCUMENTS`, `CURRENCY`.

**Gotchas (load-bearing):**
- `receiver_iva_cond` (key de `BILL_TYPE`) determina el `cbte_type` — distinto de `issuer_iva_cond` y de `receiver_iva_condition` (RG 5616). Ver glosario.
- **Tras timeout en `authorize!` no reintentar a ciegas**: el comprobante pudo emitirse en AFIP — verificar con `invoice_informed?` (`docs/consumed/afip.md §c`).
- AFIP exige TLS ≥1.2; el default `SNOOPY_SSL_VERSION=:TLSv1` quedó desactualizado (`docs/config/configuracion.md §f`).
- `pkey`/`cert`/`cuit` son secretos: setear en el host, nunca commitear.
- La gema **parchea globalmente** `String`/`Hash`/`Float` (core_ext) — posible colisión con ActiveSupport.

## Índice de artefactos

| capa | path | nota |
|---|---|---|
| interfaz | [`docs/interface/interface.md`](../docs/interface/interface.md) | API Ruby pública |
| comportamiento | [`docs/behavior/behavior.md`](../docs/behavior/behavior.md) | secuencias WSAA/WSFE |
| glosario | [`docs/glossary/glossary.md`](../docs/glossary/glossary.md) | términos AFIP |
| consumidas | [`docs/consumed/afip.md`](../docs/consumed/afip.md) | SOAP WSAA + WSFE |
| errores | [`docs/errors/errors.md`](../docs/errors/errors.md) | excepciones + política |
| configuración | [`docs/config/configuracion.md`](../docs/config/configuracion.md) | opciones runtime |
| topología | [`docs/topology/topology.md`](../docs/topology/topology.md) | deps + externos |
| test | [`docs/test/testing.md`](../docs/test/testing.md) | suite + gaps |
| operaciones (api) · datos · eventos · multi-tenancy | n/a | gema SOAP sin HTTP/DB/eventos |

## Uso correcto / gotchas

- Homologación vs producción se elige por `auth_url`/`service_url` — riesgo de emitir contra prod por error.
- Errores de negocio de AFIP **no** levantan excepción: se leen en `afip_errors`/`afip_events`/`afip_observations`.
- La suite RSpec actual está desactualizada respecto al código (ver `docs/test/testing.md`) — no asumir cobertura.
