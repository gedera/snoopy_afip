# Comportamiento — snoopy_afip
> meta: artefacto · RFC-007 · generado arch-enrich · anclado a 7813cf2 · cobertura: 3 flujos documentados / 0 pendientes localizados

## Cobertura

| flujo | estado |
|---|---|
| Autenticación WSAA (`authenticate!`) | documentado |
| Numeración del comprobante (`set_bill_number!`) | documentado |
| Autorización WSFE (`authorize!`) | documentado |
| Consulta de comprobante (`invoice_informed?`) | no documentado (variante de lectura de `fe_comp_consultar`) |

## 1. Resumen

Dos flujos de negocio encadenados: autenticación (WSAA, una vez por 12h) y autorización (WSFE, por comprobante). El segundo asume credenciales ya obtenidas. El diseño separa el parseo de la respuesta WSFE en capas que no se tumban entre sí.

## 2. Flujos

### Autenticación WSAA — `authenticate!`

Contexto: obtiene `token`/`sign` firmando un TRA con cert+pkey.

```mermaid
sequenceDiagram
  participant Host
  participant Auth as AuthenticationAdapter
  participant Cli as Client
  participant WSAA as AFIP WSAA
  Host->>Auth: new(pkey, cert)
  Host->>Auth: authenticate!
  Auth->>Auth: build_tra (XML loginTicketRequest)
  Auth->>Auth: build_cms (PKCS7 sign cert+pkey)
  Auth->>Cli: call(:login_cms, in0 cms)
  Cli->>WSAA: SOAP login_cms
  WSAA-->>Cli: loginTicketResponse
  Cli-->>Auth: body
  Auth->>Auth: Nori.parse + extrae credentials
  Auth-->>Host: {token, sign, expiration_time}
```

### Autorización WSFE — `set_bill_number!` + `authorize!`

Contexto: numera y autoriza un `Bill` válido; setea CAE y parsea errores/eventos/observaciones en capas independientes.

```mermaid
sequenceDiagram
  participant Host
  participant Adapter as AuthorizeAdapter
  participant Bill
  participant Cli as Client
  participant WSFE as AFIP WSFE
  Host->>Adapter: new(bill, token, sign, cuit, pkey, cert)
  Host->>Adapter: set_bill_number!
  Adapter->>Cli: call(:fe_comp_ultimo_autorizado)
  Cli->>WSFE: SOAP
  WSFE-->>Adapter: cbte_nro
  Adapter->>Bill: number = cbte_nro + 1
  Host->>Adapter: authorize!
  Adapter->>Bill: valid?
  alt bill invalido
    Adapter-->>Host: false
  else valido
    Adapter->>Adapter: build_body_request (FeCAEReq)
    Adapter->>Cli: call(:fecae_solicitar)
    Cli->>WSFE: SOAP
    WSFE-->>Adapter: FECAEDetResponse
    Adapter->>Bill: cae, due_date_cae, result, number
    Adapter->>Adapter: parse_errors / parse_events / parse_observations
    Adapter-->>Host: true
  end
```

## 3. Inferencias

| ítem | confidence | a verificar |
|---|---|---|
| `set_bill_number!` se llama antes de `authorize!` | inferred | el README los muestra en ese orden; confirmar si `authorize!` exige número previo |
| El parseo en capas no propaga (acumula en `errors`/`afip_*`) | declared | diseño "No Explota" del README; confirmado en código |

## 4. Cobertura y fronteras

- `invoice_informed?` (lectura `fe_comp_consultar`) no diagramado — acreta en próximo PR que lo toque.
- La firma CMS/OpenSSL detallada (PKCS7) no se desglosa; ver `build_cms`.
- Comportamiento de fallo (timeout/degradación) → `docs/consumed/afip.md §e`.
