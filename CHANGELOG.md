# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [4.3.1] - 2026-06-29
### Fixed
- `AuthorizeAdapter`: los rescues de parseo registraban con `errors << …` sobre un Hash (NoMethodError) y la consulta referenciaba una constante mal namespaceada (NameError), enmascarando el error real de AFIP. Ahora registran el mensaje sin explotar — sostiene el diseño "No Explota" (#10).
- `Snoopy::Exception::ServerTimeout` quedaba fuera de la jerarquía de la gema, así que `rescue` de la base no lo atrapaba (#11).

### Added
- `Snoopy::Exception::Error`: módulo paraguas para `rescue` de todos los errores de la gema (incluido el timeout) sin romper `rescue Timeout::Error` (#11).

### Removed
- `Snoopy.auth_hash`: código muerto que siempre levantaba NameError (constantes `Snoopy::TOKEN`/`Snoopy::SIGN` inexistentes) (#12).

### Changed
- Higiene del `.gemspec` (`required_ruby_version >= 2.5`, fecha automática).
- Suite RSpec reescrita contra la API actual y `Gemfile.lock` regenerado (#13).
- Documentación de arquitectura (`docs/<capa>/`, README, `skill/SKILL.md`) regenerada.
- CI y publicación a RubyGems automatizados por GitHub Actions (tag `v*`).

## [3.0.2] - July 14, 2017
### Added
- `Cms Builder exception`.

## [3.0.0] - June 29, 2017
### Added
- `Authentication Class` destinada a la comunicación con el **WSAA**.
- `Authorize Class` destinada a la comunicación con el **WSFE**.
- `Client Class` destinada para crear el cliente de `Savon`.
- Mejor manejo de Exceptions.
- Validaciones en el modelo `Bill`.

### Changed
- Se pasó toda la logica de comunicación con el **WSFE** del modelo `Bill` al modelo `Authorize`.
- No se crea mas el rchivo para la clave privada, devuelve en RAW.
- No se crea mas un archivo para almacenar el _token_, _sign_, se devuelve en RAW.
- Evitar raisear si se logró autorizar una factura con el **WSFE**. Manejo en el errors del `Bill` o el `Authorize`.

### Removed
- Eliminiado modulo `AuthData`.
- Eliminado el uso de `Bash` para autenticar en el **WSAA**.
