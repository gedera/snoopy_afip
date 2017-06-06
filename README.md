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

http://www.afip.gov.ar/fe/documentos/manual_desarrollador_COMPG_v2_4.pdf
http://www.afip.gob.ar/fe/documentos/manual_desarrollador_COMPG_v2_9.pdf

* Es recomendable descargar los wsdl para evitar tener que pedirlo en cada request

https://wswhomo.afip.gov.ar/wsfev1/service.asmx?wsdl  Para entorno de desarrollo
https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL Para entorno de producción

* Explicación detallada de los pasos a seguir para obtener el certificado para emitir facturas electrónicas.

https://www.afip.gob.ar/ws/WSAA/WSAA.ObtenerCertificado.pdf



## USO

### Inicialización de parametros generales

```ruby
Snoopy.default_currency      = :peso
Snoopy.default_concept       = 'Servicios'
Snoopy.default_document_type = 'CUIT'
# Para el caso de produccion
Snoopy.auth_url    = "https://wsaa.afip.gov.ar/ws/services/LoginCms" 
Snoopy.service_url = "prod.wsdl" # PATH del wdsl de producción descargado
# Para el caso de desarrollo
Snoopy.auth_url    = "https://wsaahomo.afip.gov.ar/ws/services/LoginCms"
Snoopy.service_url = "testing.wsdl" # PATH del wdsl de testing descargado
```

En caso de trabajar con `Ruby on Rails`, es recomendable crear un archivo con esta conf en `config/initializers`.

### Generar Clave privada
```ruby
Snoopy::AuthData.generate_pkey(tmp_pkey_path)
```
Donde `tmp_pkey_path` es la ruta donde se quiere que se guarde la pkey.

### Generar solicitud de pedido de certificado

```ruby
Snoopy::AuthData.generate_certificate_request(pkey_path, subj_o, subj_cn, subj_cuit, certificate_request_path)
```

* `pkey_path`: Ruta absoluta de la llave privada.
* `subj_o`: Nombre de la compañia.
* `subj_cn`: Hostname del server que generar las solicitudesm en ruby se obtiene con `%x(hostname).chomp`
* `subj_cuit`: Cuit registrado en la AFIP de la compañia que emita facturas.
* `certificate_request_path`: Ruta donde queres que se guarde el pedido de certificado.

Una vez generado este archivo debe hacerse el tramite en el sitio web de la AFIP para obtener el certificado que les permitirá emitir facturas al webservice.

<!-- Snoopy::AuthData.generate_auth_file(data) -->

<!-- data[:pkey] pkey_path, -->
<!-- data[:cert]          certificate_path, -->
<!-- data[:taxpayer]cuit: taxpayer_identification_number, -->
<!--           sale_point: sale_point, -->
<!--           own_iva_cond: vat_condition == ArgentinaResponsableMonotributo ? :responsable_monotributo : :responsable_inscripto -->

### Verficar comunicación con servicio

Una vez obtenido el certificado desde el sitio web de la AFIP, es recomendable verificar si la comunicación con el webservice de la AFIP se establecio de manera correcta, para asegurarse de que el certificado es correcto.

```ruby
Snoopy::AuthData.generate_auth_file(data)
```

* `data[:pkey]`         PATH de la clave privada (Utilizada para generar el pedido del certificado).
* `data[:cert]`         PATH del certificado otorgado por la AFIP.
* `data[:cuit]`         CUIT del emisor de la factura.
* `data[:sale_point]`   Punto de venta del emisor de la factura.
* `data[:own_iva_cond]` Condición de iva del emiso de factura. [`:responsable_monotributo` o `:responsable_inscripto`]

### Informar factura
Siempre para informar una factura debe de definirse un hash con los siguientes key, value:

* `attrs[:pkey]`                    PATH de la clave privada (Utilizada para generar el pedido del certificado).
* `attrs[:cert]`                    PATH del certificado otorgado por la afip.
* `attrs[:cuit]`                    CUIT del emisor de la factura.
* `attrs[:sale_point]`              Punto de venta del emisor de la factura.
* `attrs[:own_iva_cond]`            Condición de iva del emisor de la factura. [`:responsable_monotributo` o `:responsable_inscripto`]
* `attrs[:net]`                     Monto neto por defecto es 0.
* `attrs[:document_type]`           Tipo de documento a utilizar, por default Snoopy.default_documento [`"CUIT"`, `"DNI"`, `"Doc. (Otro)"`].
* `attrs[:currency]`                Tipo de moneda a utilizar por default Snoopy.default_moneda.
* `attrs[:concept]`                 Concepto de la factura por defecto Snoopy.default_concepto.
* `attrs[:doc_num]`                 Numero de documento.
* `attrs[:service_date_from]`       Inicio de vigencia de la factura.
* `attrs[:service_date_to]`         Fin de vigencia de la factura.
* `attrs[:cbte_asoc_to_sale_point]` Esto es el punto de venta de la factura para la nota de crédito (Solo pasar si se esta creando una nota de crédito).
* `attrs[:cbte_asoc_num]`           Esto es el numero de factura para la nota de crédito (Solo pasar si se esta creando una nota de crédito).
* `attrs[:iva_cond]`                Condición de iva.
* `attrs[:imp_iva]`                 Monto total de impuestos.
* `attrs[:alicivas]`                Impuestos asociados a la factura.

El `attrs[:alicivas]` discrimina la información de los items. Es posible que en la factura se discrimine diferentes items con diferentes impuestos. Para ello el `attrs[:alicivas]` es un arreglo de hashes. Donde cada uno de ellos contenga la información sobre un determinado impuesto.

```ruby
{ id:         tax_rate.round_with_precision(2),    # Porcentaje. Ej: "0.105", "0.21", "0.27"
  amount:     tax_amount.round_with_precision(2),  # Monto total del item.
  net_amount: net_amount.round_with_precision(2) } # Monto de base imponible.
```

Por ejemplo si se tiene 5 items, donde 3 de ellos tienen un impuesto del 10.5% y los 2 restantes del 21%. Los primeros 3 deben, se debera de crear dos hashes de la siguientes forma.

```ruby
attrs[:alicivas] = [ { id: (10.5 / 100 ).to_s 
                       amount: X,            # De los 3 items de 10.5
                       net_amount: Y },
                     { id: (21 / 100 ).to_s 
                       amount: X,            # De los 2 items de 21
                       net_amount: Y } ]
```
Donde: 

* `X`: Es la suma total de los items que corresponda.
* `Y`: Base imponible de la suma de los items que corresponda.

Los `tax_rates` soportados por AFIP son los siguientes:

```ruby
Snoopy::ALIC_IVA
```

#### Tips:

La base imponible se calcula de la siguiente manera:

```ruby
total_amount / (1 + tax_percentage)
```

Finalmente para informar la factura a AFIP simplemente:

```ruby
bill = Snoopy::Bill.new(attr) # construyo el objeto bill.
bill.cae_request # Informo Afip la factura.
```

### Resultado obtenido desde la Afip

Una vez llamado al metodo `cae_request` podemos verificar el resultado en el objeto bill.

```ruby
bill.approved? # Salio todo bien en la AFIP con la factura informada.
bill.partial_approved? # Aprobada parcialmente.
bill.rejected? # Rechazada algo esta mal.
bill.response # Respuesta completa de AFIP.
bill.events # Eventos entregados por la AFIP.
bill.observations # Observaciones entregadas por la AFIP.
bill.errors # Errores generados dentro de la gema o  entregados por la AFIP.
bill.backtrace # En caso de ocurrir un error dentro de la gema.
```

### Manejo de excepciones

Hay errores que producirán que la gema generé un raise, estos son los casos que se produzcan errores previo o durante la comunicación con la AFIP. En estos casos se produce un `raise` debido a que no se aseguro respuesta valida de la AFIP.

Existe otro caso que se produzca un error posterior a la comunicación, en este caso se pudo obtener una respuesta de AFIP (puede consultarse `bill.response` para obtener la respuesta completa de la AFIP), pero se producierón errores en el parseo de la misma, para ellos se puede consultar las exceptiones generadas por los parseadores con `bill.exceptions`. 
Se devulven excepciones debido a que si bien se ha producido un error, la comunicación con la AFIP se realizo exitosamente, pero errores al momento de parsear la respuesta, en esta situación no es posible saber si se emitio con exito o no la factura. Esto es una contingencia de que AFIP cambien el XML lo cual producirá error al momento de parsear la respuesta.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
