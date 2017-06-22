# coding: utf-8
module Snoopy
  module AuthData
    # def self.current_token_sign_file(cuit)
    #   "/tmp/snoopy_afip_#{cuit}_#{Date.today.strftime('%d_%m_%Y')}.yml"
    # end

    # def self.generate_auth_file(cuit, pkey, cert)
    #   raise "Debe definir el cuit del emisor"                   unless cuit
    #   raise "Archivo certificado no encontrado en #{cert}"      unless File.exists? cert
    #   raise "Archivo de llave privada no encontrado en #{pkey}" unless File.exists? pkey

    #   todays_datafile = Snoopy::AuthData.current_token_sign_file(cuit)

    #   %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh -u #{Snoopy.auth_url} -k #{pkey} -c #{cert} -i #{cuit}) unless File.exists?(todays_datafile)

    #   # Si no se creo el archivo todays_datafile es por que algo esta mal,
    #   # puede que este mal el certificado o el CUIT. La pkey no va estar mal por que la genero yo.
    #   # El tema es que revisando el XML que devuelve la AFIP solo dice ERROR pero no dice nada mas.
    #   File.exists?(todays_datafile)
    # end
  end
end
