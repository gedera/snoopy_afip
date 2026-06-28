# snoopy_afip

Gema Ruby que adapta la **Facturación Electrónica de AFIP (Argentina)**. Expone el módulo `Snoopy` y resuelve, vía SOAP (`savon`), los dos servicios de AFIP necesarios para emitir comprobantes electrónicos:

- **WSAA** (autenticación): obtiene `token`/`sign` a partir de clave privada + certificado.
- **WSFE** (facturación electrónica v1): autoriza facturas y notas de crédito, devuelve el CAE.

Versión actual: `4.3.0`.

## Instalación

```ruby
# Gemfile
gem 'snoopy_afip'
```

```bash
bundle install
# o
gem install snoopy_afip
```

## Setup (desarrollo)

```bash
bundle install
bundle exec rspec   # ver estado de la suite en docs/test/testing.md
```

Dependencia de runtime: `savon ~> 2.12.1`. Gestión de Ruby con **chruby**, dependencias con **Bundler**.

## Configuración

La gema se configura en el host (típicamente `config/initializers/snoopy.rb`):

```ruby
Snoopy.default_currency      = :peso
Snoopy.default_concept       = 'Servicios'
Snoopy.default_document_type = 'CUIT'           # alguna key de Snoopy::DOCUMENTS

# Homologación (testing)
Snoopy.auth_url    = 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl'
Snoopy.service_url = 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx?wsdl'
# Producción
# Snoopy.auth_url    = 'https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl'
# Snoopy.service_url = 'https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL'

Snoopy.pkey = '<path-o-PEM-de-la-clave-privada>'   # secreto — nunca commitear
Snoopy.cert = '<path-o-PEM-del-certificado-AFIP>'  # secreto — nunca commitear
Snoopy.cuit = '<CUIT-del-emisor>'
```

> El inventario completo de opciones (tipos, defaults, secretos, failure-mode) está en [`docs/config/configuracion.md`](docs/config/configuracion.md). Nunca incrustar CUIT, claves ni certificados reales en el código ni en el repo.

## Uso

### 1. Autenticar (WSAA)

```ruby
auth = Snoopy::AuthenticationAdapter.new(pkey: pkey_path, cert: cert_path)
credentials = auth.authenticate!
# => { token: "<token>", sign: "<sign>", expiration_time: <DateTime> }  (válido 12h)
```

Helpers para generar clave/CSR: `Snoopy::AuthenticationAdapter.generate_pkey`, `.generate_certificate_request_with_ruby`, `.generate_certificate_request_with_bash`. Trámite del certificado: [AFIP — Obtener certificado](https://www.afip.gob.ar/ws/WSAA/WSAA.ObtenerCertificado.pdf).

### 2. Crear el comprobante (`Bill`)

```ruby
bill = Snoopy::Bill.new(
  cuit:                   cuit,
  sale_point:             sale_point,
  concept:                'Servicios',
  document_type:          'CUIT',
  document_num:           '30710151543',
  issuer_iva_cond:        Snoopy::RESPONSABLE_INSCRIPTO,
  receiver_iva_cond:      :factura_a,           # key de Snoopy::BILL_TYPE → cbte_type
  receiver_iva_condition: :responsable_inscripto,
  total_net:             1000.0,
  alicivas: [ { id: 0.21, amount: 210.0, taxeable_base: 1000.0 } ]
)
bill.valid?   # corre validaciones → bill.errors
```

`alicivas` discrimina el IVA por ítem (`id` = porcentaje, `amount` = monto del impuesto, `taxeable_base` = neto sin IVA). Tasas soportadas: `Snoopy::ALIC_IVA`. Detalle de términos en [`docs/glossary/glossary.md`](docs/glossary/glossary.md).

### 3. Autorizar (WSFE)

```ruby
adapter = Snoopy::AuthorizeAdapter.new(
  bill:  bill,
  pkey:  pkey, cert: cert, cuit: cuit,
  token: credentials[:token], sign: credentials[:sign]
)
adapter.set_bill_number!   # numera con el último autorizado + 1
adapter.authorize!         # => true/false; setea bill.cae, bill.result, ...
```

Lecturas de la respuesta: `adapter.afip_errors`, `adapter.afip_events`, `adapter.afip_observations`, `adapter.errors`, `adapter.response`. Estado del comprobante: `bill.approved?`, `bill.partial_approved?`, `bill.rejected?`.

### Manejo de errores

- **Explota** (`raise`): fallo de comunicación con AFIP (`Snoopy::Exception::ServerTimeout`, `ClientError`) → no se autorizó el comprobante.
- **No explota**: AFIP respondió pero el parseo de la respuesta falló o devolvió errores de negocio → se acumulan en `adapter.errors` / `afip_errors` (parseo en 4 capas independientes para que un cambio de formato de AFIP no tumbe todo).

Catálogo y política completos en [`docs/errors/errors.md`](docs/errors/errors.md).

## Índice de artefactos (`docs/`)

| capa | artefacto | contenido |
|---|---|---|
| interfaz | [`docs/interface/interface.md`](docs/interface/interface.md) | API Ruby pública (`Snoopy`, adapters, `Bill`, constantes) |
| comportamiento | [`docs/behavior/behavior.md`](docs/behavior/behavior.md) | secuencias WSAA / WSFE |
| glosario | [`docs/glossary/glossary.md`](docs/glossary/glossary.md) | términos AFIP (CAE, cbte_type, alicivas, IVA cond) |
| consumidas | [`docs/consumed/afip.md`](docs/consumed/afip.md) | contrato SOAP consumido (WSAA + WSFE) |
| errores | [`docs/errors/errors.md`](docs/errors/errors.md) | jerarquía `Snoopy::Exception::*` + política |
| configuración | [`docs/config/configuracion.md`](docs/config/configuracion.md) | inventario de opciones runtime |
| topología | [`docs/topology/topology.md`](docs/topology/topology.md) | dependencias + servicios externos |
| test | [`docs/test/testing.md`](docs/test/testing.md) | suite, gaps de cobertura |
| operaciones (api) | n/a | gema sin superficie HTTP/CLI propia |
| datos | n/a | sin base de datos |
| eventos · multi-tenancy | n/a | no aplica |

## Referencias AFIP

- [Especificación Técnica WSAA 1.2.0](http://www.afip.gov.ar/ws/WSAA/Especificacion_Tecnica_WSAA_1.2.0.pdf)
- [Manual del desarrollador WSFE](http://www.afip.gob.ar/fe/documentos/manual_desarrollador_COMPG_v2_9.pdf)

## TO DO

- Mejor parseo de los errores de AFIP (mapear cada código al atributo del `Bill`).
- Batch: autorizar un pool de `Bill` en una sola request.

## License

MIT — ver [LICENSE.txt](LICENSE.txt).
