# Topología — snoopy_afip
> meta: artefacto · RFC-006 · generado arch-structure · anclado a 7813cf2 · cobertura: deps de runtime + servicios externos AFIP

## 1. Resumen

Gema cliente SOAP. Una sola dependencia de runtime declarada en el `.gemspec` (`savon`), que arrastra el stack SOAP (httpi, nori, gyoku, akami, wasabi, nokogiri). Consume dos servicios SOAP externos de AFIP: WSAA (auth) y WSFE (facturación). No corre como proceso propio: se embebe en el host (típicamente una app Rails).

## 2. Dependencias

| nombre | versión | rol |
|---|---|---|
| `savon` | `~> 2.12.1` (gemspec) · `2.12.0` (lock) | cliente SOAP — única dep de runtime declarada |
| `httpi` | `2.4.4` (lock, transitiva) | capa HTTP de savon |
| `nori` | `2.6.0` (lock, transitiva) | XML→Hash (usado directo en `AuthenticationAdapter`) |
| `nokogiri` | `1.10.9` (lock, transitiva) | parser XML; usado directo en `build_tra` (`Nokogiri::XML::Builder`) |
| `gyoku` `akami` `wasabi` `builder` `rack` `socksify` `mini_portile2` | ver lock | transitivas de savon |
| `OpenSSL` (stdlib) | — | firma CMS/PKCS7, generación de clave/CSR |
| `Timeout` (stdlib) | — | corta llamadas SOAP (`Snoopy::Client#call`) |

## 3. Grafo

```mermaid
flowchart LR
  Host["App host (Rails)"] -->|require| Snoopy["snoopy_afip"]
  Snoopy -->|Savon.client| Savon["savon (SOAP)"]
  Savon -->|HTTP/SOAP| WSAA["AFIP WSAA<br>login_cms"]
  Savon -->|HTTP/SOAP| WSFE["AFIP WSFE<br>fecae_solicitar / fe_comp_*"]
  Snoopy -->|firma CMS| OpenSSL["OpenSSL (stdlib)"]
  Snoopy -->|build_tra| Nokogiri["nokogiri"]
  Snoopy -->|parse| Nori["nori"]
```

## 4. Modos de ejecución

| modo | aplica | nota |
|---|---|---|
| librería embebida | sí | se usa dentro del proceso del host; sin daemon/worker propio |
| web / worker / cron propios | no | la gema no define procesos |

## 5. Cobertura y fronteras

- **`Gemfile.lock` divergente** (ver `docs/test/` y nota global): el lock fija `snoopy_afip (4.0.1)` mientras `version.rb` dice `4.3.0`, y lista en `PATH specs` deps (`akami`, `nokogiri`, `nori`, `wasabi`) que el `.gemspec` **actual** no declara explícitamente (solo `savon`). El lock parece no regenerado tras cambios de gemspec/versión. Versiones de la tabla tomadas del lock como mejor evidencia disponible, marcadas.
- Servicios AFIP externos (WSAA/WSFE): contrato consumido en `docs/consumed/` (RFC-018).
- Topología upstream de AFIP (infra del organismo) fuera de alcance.
