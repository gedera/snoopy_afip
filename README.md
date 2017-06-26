# snoopy_afip
conexión con Web Service de Factura Electrónica de AFIP (WSFE)

## Instalación

Añadir esta linea en el Gemfile:

```ruby
gem 'snoopy_afip'
```

Luego ejecuta:

    $ bundle

O instala la gema a mano:

    $ gem install snoopy_afip

## Antes que nada

* Link con el manual para desarrolladores.

- [Especificación Técnica WSAA]('http://www.afip.gov.ar/ws/WSAA/Especificacion_Tecnica_WSAA_1.2.0.pdf'): Especificación técnica para la comunicación con el **WSAA** (servicio de autenticación), su propósito es solicitar un _tocken_ y _sign_ para poder emitir facturas con el servicio de **WSFE** (Servicio de autorización de facturas)

- [Manual desarrollador](http://www.afip.gob.ar/fe/documentos/manual_desarrollador_COMPG_v2_9.pdf): Especificación técnica para la comunicación con **WSFE** (Servicio de autorización de facturas).

* Es recomendable descargar los **Wsdl** para evitar tener que pedirlo en cada request

- Wsdl **WSAA** (servicio de autenticación)

  - Testing:    [https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl]('https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl')
  - Producción: [https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl]('https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl')

- **WSFE** (Servicio de autorización de facturas)

  - Testing:    [https://wswhomo.afip.gov.ar/wsfev1/service.asmx?wsdl]('https://wswhomo.afip.gov.ar/wsfev1/service.asmx?wsdl')
  - Producción: [https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL]('https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL')

* Explicación detallada de los pasos a seguir para obtener el certificado desde el sitio web AFIP para emitir facturas electrónicas.

[obtención de certificado](https://www.afip.gob.ar/ws/WSAA/WSAA.ObtenerCertificado.pdf)

## USO

### Inicialización de parametros generales

```ruby
Snoopy.default_currency      = :peso
Snoopy.default_concept       = 'Servicios'
Snoopy.default_document_type = 'CUIT' || 'DNI' # O alguna key de Snoopy::DOCUMENTS
# Para el caso de produccion
Snoopy.auth_url    = 'https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl' || PATH_WSAA_PROP_WSDL
Snoopy.service_url = 'https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL' || PATH_WSFE_PROP_WSDL
# Para el caso de desarrollo
Snoopy.auth_url    = 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl' || PATH_WSAA_TEST_WSDL
Snoopy.service_url = 'https://wswhomo.afip.gov.ar/wsfev1/service.asmx?wsdl' || PATH_WSFE_TEST_WSDL
```

En caso de trabajar con `Ruby on Rails`, es recomendable crear un archivo con esta conf en `config/initializers/snoopy.rb`.

### Generar Clave privada

```ruby
Snoopy::AuthenticationAdapter.generate_pkey(2048) # Si no se pasa argumento se generar una de 8192
```

Este metodo retorna el `RAW` de la pkey, la cual debera guardarse en algun archivo o alguna base de datos.

### Generar solicitud de pedido de certificado

#### With ruby

Este metodo aun no ha sido testeado, por lo que agredezco si alguien logra probarlo.

```ruby
Snoopy::AuthenticationAdapter.generate_certificate_request_with_ruby(pkey_path, subj_o, subj_cn, subj_cuit)
```

#### With bash

Mantiene la generación de versiones pasadas de `Snoopy`

```bash
Snoopy::AuthenticationAdapter.generate_certificate_request_with_bash(pkey_path, subj_o, subj_cn, subj_cuit)
```

- `pkey_path`: Ruta absoluta de la llave privada.
- `subj_o`: Nombre de la compañia.
- `subj_cn`: Hostname del server que generará las solicitudes. En ruby se obtiene con `%x(hostname).chomp`
- `subj_cuit`: Cuit registrado en la AFIP de la compañia que emita facturas.

Una vez generado este archivo debe hacerse el tramite en el sitio web de la **AFIP** para obtener el certificado que permitirá autorizar facturas al webservice.

### Solicitar autorización para la emisión de facturas

Para poder emitir o autorizar facturas en el web service de la **AFIP** es necesario solicitar autorización.

```ruby
# pkey_path: Ruta absoluta de la llave privada.
# cert_path: Ruta absoluta del cetificado obtendio del sitio oficial de la **AFIP**.
authentication_adapter = Snoopy::AuthenticationAdapter.new(pkey_path, pkey_cert)
authentication_adapter.authenticate!
```

`authentication_adapter.authenticate!` deberá retornar un `Hash` con las siguientes keys: `:token`, `:sign` y `:expiration_time`

La key `:expiration_time` determina hasta cuando se podrá autorizar facturas, el tiempo esta prefijado por **AFIP** y es el de 24 Horas desde el momento de la solicitud del **token sign**, superado este tiempo deberá solicitarse nuevamente un **token sign**.

```ruby
# Response example
{ token: "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9InllcyI/Pgo8c3NvIHZlcnNpb249IjIuMCI+CiAgICA8aWQgdW5pcXVlX2lkPSI5MDIxNDczOTEiIHNyYz0iQ049d3NhYWhvbW8sIE89QUZJUCwgQz1BUiwgU0VSSUFMTlVNQkVSPUNVSVQgMzM2OTM0NTAyMzkiIGdlbl90aW1lPSIxNDk4NDk0NDQ1IiBleHBfdGltZT0iMTQ5ODUzNzcwNSIgZHN0PSJDTj13c2ZlLCBPPUFGSVAsIEM9QVIiLz4KICAgIDxvcGVyYXRpb24gdmFsdWU9ImdyYW50ZWQiIHR5cGU9ImxvZ2luIj4KICAgICAgICA8bG9naW4gdWlkPSJDPWFyLCBPPXNlcXVyZSBzYSwgU0VSSUFMTlVNQkVSPUNVSVQgMjAyNDE2MDgxNjcsIENOPXBjIiBzZXJ2aWNlPSJ3c2ZlIiByZWdtZXRob2Q9IjIyIiBlbnRpdHk9IjMzNjkzNDUwMjM5IiBhdXRobWV0aG9kPSJjbXMiPgogICAgICAgICAgICA8cmVsYXRpb25zPgogICAgICAgICAgICAgICAgPHJlbGF0aW9uIHJlbHR5cGU9IjQiIGtleT0iMjAyNDE2MDgxNjciLz4KICAgICAgICAgICAgPC9yZWxhdGlvbnM+CiAgICAgICAgPC9sb2dpbj4KICAgIDwvb3BlcmF0aW9uPgo8L3Nzbz4KCg==",
  sign: "iSpp/5qxQntuzOQcqs6GlShFaOKtEagLY17TFDwMTiErquT/fEw5ki9Ff4RYGndc/49UGmUTnVjUqB0mxuJk2IG4t+J4AAyVsY6+xiBGvMXAM/5sAI78NDl7ibMxAcdPi+nBIrdydp5DLy2SB4u/G46kguc6+srBp2fo20f/+wM=",
  expiration_time: #<DateTime: 2017-06-27T01:28:25-03:00 ((2457932j,16105s,963000000n),-10800s,2299161j)>}}
```

En caso de producirse algun tipo de error este será devuelto a traves de raise exception. El error mas comun puede deberse al que certificado obtenido a treves del pedido de cetificado no sea correcto.

### Autorizar factura

#### Crear `Bill`
```ruby
Snoopy::Bill.new(attrs)

```
Donde `attrs` debe estar conformado de la siguiente manera:
* `attrs[:cuit]`                    CUIT del emisor de la factura.
* `attrs[:concept]`                 Concepto de la factura, por defecto `Snoopy.default_concept`.
* `attrs[:imp_iva]`                 Monto total de impuestos.
* `attrs[:currency]`                Tipo de moneda a utilizar, por default `Snoopy.default_currency`.
* `attrs[:alicivas]`                Impuestos asociados a la factura.
* `attrs[:total_net]`               Monto neto por defecto es 0.
* `attrs[:sale_point]`              Punto de venta del emisor de la factura.
* `attrs[:document_type]`           Tipo de documento a utilizar, por default `Snoopy.default_document`. Valores posibles `Snoopy::DOCUMENTS`
* `attrs[:document_num]`            Numero de documento o cuit, el valor depende de `attrs[:document_type]`.
* `attrs[:issuer_iva_cond]`         Condición de IVA del emisor de la factura. [`Snoopy::RESPONSABLE_INSCRIPTO` o `Snoopy::RESPONSABLE_MONOTRIBUTO`]
* `attrs[:receiver_iva_cond]`       valores posibles `Snoopy::BILL_TYPE`
* `attrs[:service_date_from]`       Inicio de vigencia de la factura.
* `attrs[:service_date_to]`         Fin de vigencia de la factura.
* `attrs[:cbte_asoc_num]`           Numero de la factura a la cual se quiere crear una nota de crédito (Solo pasar si se esta creando una nota de crédito).
* `attrs[:cbte_asoc_to_sale_point]` Punto de venta de la factura a la cual se quiere crear una nota de crédito (Solo pasar si se esta creando una nota de crédito).

El `attrs[:alicivas]` discrimina la información de los items. Es posible que en la factura se discriminen diferentes items con diferentes impuestos. Para ello el `attrs[:alicivas]` es un arreglo de `Hash`. Donde cada uno de ellos tiene la información sobre un determinado impuesto.

```ruby
{ id:            tax_rate.round_with_precision(2),    # Porcentaje. Ej: "0.105", "0.21", "0.27"
  amount:        tax_amount.round_with_precision(2),  # Monto total del impuesto del item.
  taxeable_base: net_amount.round_with_precision(2) } # Monto total del item sin considerar el impuesto.
```

Por ejemplo si se tiene 5 items, donde 3 de ellos tienen un impuesto del 10.5% y los 2 restantes del 21%. Los primeros 3 deben, se debera de crear dos hashes de la siguientes forma.

```ruby
attrs[:alicivas] = [ { id: (10.5 / 100 ).to_s 
                       amount: X,            # De los 3 items de 10.5
                       taxeable_base: Y },   # De los 3 items de 10.5
                     { id: (21 / 100 ).to_s 
                       amount: X,            # De los 2 items de 21
                       taxeable_base: Y } ]  # De los 2 items de 21
```
Donde: 

* `X`: Es la parte del monto que le corresponde al impuesto.
* `Y`: Es la partes del monto sin impuesto.

Los `tax_rates` soportados por AFIP son los siguientes:

```ruby
Snoopy::ALIC_IVA
```

* Tips:

El `taxeable_base` se calcula de la siguiente manera:

```ruby
total_amount / (1 + tax_percentage)
```
  
- Metodos de interes
  - **valid?**            valida si la `bill` cumple lo minimo indispensable.
  - **partial_approved?** si fue _Aprobada parcialmente_ por el webserice.
  - **rejected?**         si fue _Rechazada_ por el webservice.
  - **approved?**         si fue _Aprobada_ por el webservice.
  - **errors**            errores presentados durante la validación `valid?`

#### Autorizar el `Bill`
```ruby
authorize_adapter = Snoopy::AuthorizeAdapter.new({ bill: bill,        # Obtenido en el paso anterior
                                                   pkey: pkey,        # PATH de la clave privada generada anteriormente.
                                                   cert: certificate, # PATH del certificado descargado del sitio web de la AFIP.
                                                   cuit: cuit,        # CUIT del emisor de la factura, mismo con el que se hizo el tramite.
                                                   sign: sign,        # SIGN obtenido en la autenticación
                                                   token: token})     # TOKEN obtenido en la autenticación
                                                   
authorize_adapter.authorize!
```

- Metodos de interes del `Snoopy::AuthorizeAdapter`

  - **request** Información enviada al webservice de **AFIP**
  - **response** Respuesta completa obtenida del webservice de **AFIP**
  - **afip_errors** Errores parseados de la **response**. Pueden presentarse los motivos por los que no se autorizo la `bill`
  - **afip_events** Eventos parseados de la **response** . Generalmente la **AFIP** los usa para informar de posibles cambios.
  - **afip_observations** Observaciones parseados de la **response**. Pueden presentarse los motivos por los que no se autorizo la `bill`
  - **errors** Errores presentados en el proceso de autorización. Explicado en el apartado siguiente.

### Manejo de excepciones

#### Explota

Hay errores que producirán que `Snoopy` generé un `raise`, estos son los casos que se produzcan errores previo o durante la comunicación con la **AFIP**. En estos casos se produce un `raise` debido a que no se logro la comunicación con la **AFIP** por lo que se puede asegurar que no se autorizo la `bill`

#### No Explota
Existe otro caso que se produzca un error posterior a la comunicación con el webservice, en este caso se pudo obtener una respuesta , pero se producierón errores en el parseo de la misma (Por ejemplo **AFIP** cambia el formato de la response), para ellos se puede consultar las exceptiones generadas por los parseadores con `authorize_adapter.errors`. 

Hay 4 nivel de parser:
- **Obtención del resultado, cae, fecha de vencimiento del cae y el bill number**: Este es el nivel de parser mas **importante** dado que si este no se pudo realizar, es imposible saber que sucedio durante la autorización. Pero no preocuparse por que esta la response completa en `authorize_adapter.response`
- **Parseo de errores**: Parsea los errores retornados por la **AFIP**.
- **Parseo de eventos**: Parsea los eventos retornados por la **AFIP**.
- **Parseo de observaciones**: Parsea las observaciones retornados por la **AFIP**.

Implemente esto de esta manera debido a que sucedio que **AFIP** cambio algo en la estructura de los eventos, y al tener todo en un solo parser explotaba todo y no sabia que habia sucedido con la autorización de la factura.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
