require "bundler/setup"
require "bravo/version"
require "bravo/constants"
require "savon"
require "bravo/core_ext/float"
require "bravo/core_ext/hash"
require "bravo/core_ext/string"
module Bravo

  class NullOrInvalidAttribute < StandardError; end

  autoload :Authorizer,   "bravo/authorizer"
  autoload :AuthData,     "bravo/auth_data"
  autoload :Bill,         "bravo/bill"
  autoload :Constants,    "bravo/constants"


  extend self
  attr_accessor :cuit, :sale_point, :service_url, :default_documento, :pkey, :cert,
    :default_concepto, :default_moneda, :own_iva_cond, :verbose, :auth_url

  def auth_hash
    {"Token" => Bravo::TOKEN, "Sign"  => Bravo::SIGN, "Cuit"  => Bravo.cuit}
  end

  def bill_types
    [
      ["Factura A", "01"],
      # ["Nota de Débito A", "02"],
      ["Nota de Crédito A", "03"],
      # ["Recibos A", "04"],
      # ["Notas de Venta al contado A", "05"],
      ["Factura B", "06"],
      # ["Nota de Debito B", "07"],
      ["Nota de Credito B", "08"],
      # ["Recibos B", "09"],
      # ["Notas de Venta al contado B", "10"],
      ["Factura C", "11"],
      ["Nota de Crédito C", "13"],
      # ["Cbtes. A del Anexo I, Apartado A,inc.f),R.G.Nro. 1415", "34"],
      # ["Cbtes. B del Anexo I,Apartado A,inc. f),R.G. Nro. 1415", "35"],
      # ["Otros comprobantes A que cumplan con R.G.Nro. 1415", "39"],
      # ["Otros comprobantes B que cumplan con R.G.Nro. 1415", "40"],
      # ["Cta de Vta y Liquido prod. A", "60"],
      # ["Cta de Vta y Liquido prod. B", "61"],
      # ["Liquidacion A", "63"],
      # ["Liquidacion B, "64""]
    ]
  end

#  Savon::Request.log = false unless (Bravo.verbose == "true") || (ENV["VERBOSE"] == true)

#  Savon.configure do |config|
#    config.log = Bravo.log?
#    config.log_level = :debug
#  end

end
