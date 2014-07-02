$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'snoopy'
require 'rspec'
require 'ruby-debug'

class SpecHelper
  include Savon::Logger
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Snoopy.pkey = "spec/fixtures/pkey"
Snoopy.cert = "spec/fixtures/cert.crt"
Snoopy.cuit = ENV["CUIT"] || raise(Snoopy::NullOrInvalidAttribute.new, "Please set CUIT env variable.")
Snoopy.sale_point = "0002"
Snoopy.auth_url = "https://wsaahomo.afip.gov.ar/ws/services/LoginCms"
Snoopy.service_url = "http://wswhomo.afip.gov.ar/wsfev1/service.asmx?WSDL"
Snoopy.default_concepto = "Productos y Servicios"
Snoopy.default_documento = "CUIT"
Snoopy.default_moneda = :peso
Snoopy.own_iva_cond = :responsable_inscripto
