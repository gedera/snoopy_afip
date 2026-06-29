$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "snoopy_afip"
# Bill#valid? usa blank?/present? (ActiveSupport); en producción lo provee Rails.
require "active_support/core_ext/object/blank"
require "rspec"

# Config base de homologación para construir adapters en los specs.
# Nunca credenciales reales: pkey/cert/cuit son placeholders de prueba.
Snoopy.auth_url            = "https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl"
Snoopy.service_url         = "https://wswhomo.afip.gov.ar/wsfev1/service.asmx?WSDL"
Snoopy.default_currency    = :peso
Snoopy.default_concept     = "Productos"
Snoopy.default_document_type = "CUIT"

RSpec.configure do |config|
  config.expect_with(:rspec) { |e| e.syntax = :expect }
  config.disable_monkey_patching!
end
