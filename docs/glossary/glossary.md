# Glosario — snoopy_afip
> meta: artefacto · RFC-009 · generado arch-enrich · anclado a 7813cf2 · cobertura: términos de dominio AFIP materializados en `lib/`; parcial, acreta por PR

Bounded context: facturación electrónica AFIP (Argentina). Sin capa de datos (`docs/data/` n/a) → binding a símbolo público estable (ISO 11179), no a tabla.

## WSAA

Web Service de Autenticación y Autorización de AFIP. Recibe un CMS firmado (cert + clave privada) y devuelve `token` + `sign` válidos 12h (la gema pide `to = from + 12h`). Es el prerrequisito para operar contra WSFE.

**Binding:** `Snoopy::AuthenticationAdapter` (`authentication_adapter.rb`); operación `:login_cms`.

## WSFE

Web Service de Facturación Electrónica v1 de AFIP. Autoriza comprobantes y devuelve el CAE. Requiere las credenciales de WSAA en cada request (`Auth`).

**Binding:** `Snoopy::AuthorizeAdapter` (`authorize_adapter.rb`); operaciones `:fecae_solicitar`, `:fe_comp_ultimo_autorizado`, `:fe_comp_consultar`.

## CAE (Código de Autorización Electrónico)

Código que AFIP otorga al aprobar un comprobante; sin CAE la factura no es válida. Viene con fecha de vencimiento (`cae_fch_vto`).

**Binding:** `Bill#cae`, `Bill#due_date_cae`; seteados en `AuthorizeAdapter#parse_fecae_solicitar_response`.

## CMS / TRA

**TRA** (Ticket de Requerimiento de Acceso): XML `loginTicketRequest` con `uniqueId`, `generationTime`, `expirationTime` y `service=wsfe`. **CMS**: el TRA firmado en PKCS7 (cert + pkey), base64, que se manda a WSAA.

**Binding:** `AuthenticationAdapter#build_tra` (TRA), `#build_cms` (CMS).

## cbte_type (tipo de comprobante)

Código AFIP del tipo de comprobante (Factura A/B/C, Nota de Crédito A/B/C). En la gema se **deriva** de la condición IVA del receptor (`receiver_iva_cond`), no se pasa directo.

**Binding:** `Bill#cbte_type` → `Snoopy::BILL_TYPE[receiver_iva_cond]`; tabla completa en `Snoopy::CBTE_TYPE`.

## alicivas (alícuotas de IVA)

Discriminación de IVA por ítem del comprobante: array de hashes `{id, amount, taxeable_base}` donde `id` es el porcentaje de IVA (0.105, 0.21, 0.27…) mapeado al código AFIP. Monotributistas no las informan.

**Binding:** `Bill#alicivas`, `Bill::TAX_ATTRIBUTES`; código AFIP en `Snoopy::ALIC_IVA`; armado en `AuthorizeAdapter#build_body_request` (clave `Iva`).

## Condición IVA — emisor vs receptor

Tres conceptos distintos conviven:
- **`issuer_iva_cond`** (emisor): determina si se informan alícuotas (monotributo no). Valores en `Snoopy::IVA_COND`.
- **`receiver_iva_cond`** (receptor): determina el `cbte_type` (clave de `Snoopy::BILL_TYPE`).
- **`receiver_iva_condition`** (RG 5616, "verdadera condición IVA del receptor"): id que AFIP exige en el detalle (`CondicionIVAReceptorId`). Valores en `Snoopy::IVA_COND_RECEIVER`.

**Binding:** `Bill#issuer_iva_cond`, `#receiver_iva_cond`, `#receiver_iva_condition` / `#receiver_iva_condition_id`.

## Resultado (A / P / R)

Veredicto de AFIP sobre el comprobante: `A` aprobado, `P` aprobado parcial, `R` rechazado.

**Binding:** `Bill#result`, `#approved?`, `#partial_approved?`, `#rejected?`.

## afip_errors / afip_events / afip_observations

Tres canales que AFIP devuelve en la respuesta, parseados en hashes `code => msg` separados. **Errores**: motivos de rechazo. **Eventos**: avisos de AFIP (ej. cambios futuros). **Observaciones**: motivos por los que no se autorizó. No son excepciones Ruby — el flujo no explota (ver `docs/behavior/`).

**Binding:** `AuthorizeAdapter#afip_errors/#afip_events/#afip_observations`.

## 3. Inferencias

| término | confidence | nota |
|---|---|---|
| `receiver_iva_condition` (RG 5616) | inferred | el comentario del código dice "la verdadera condición de iva del receptor"; confirmar nombre de negocio exacto |
| Candidato canónico (RFC-019) | inferred | `CAE`, `WSFE`, `condición IVA` probablemente aparecen en otros repos de facturación del fleet → candidatos a glosario canónico; arch-enrich no lo crea, lo flaggea |

## 4. Cobertura y fronteras

- Términos materializados en `lib/` actual. Acreta por PR.
- Sin `Binding:` a tabla (gema sin datos); binding a símbolo público.
- Significado de negocio profundo (reglas AFIP) fuera de alcance: referencia al manual del desarrollador AFIP (ver `docs/consumed/afip.md`).
