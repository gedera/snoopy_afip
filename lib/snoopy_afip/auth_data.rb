module Snoopy
  module AuthData
    def generate_auth_file
      raise "Debe definir el cuit del emisor"                   unless cuit
      raise "Archivo de llave privada no encontrado en #{pkey}" unless File.exists?(pkey)
      raise "Archivo certificado no encontrado en #{cert}"      unless File.exists?(cert)

      todays_datafile = "/tmp/snoopy_afip_#{cuit}_#{Time.new.strftime('%d_%m_%Y')}.yml"
      opts = "-u #{Snoopy.auth_url} -k #{pkey} -c #{cert} -i #{cuit}"

      %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh #{opts}) unless File.exists?(todays_datafile)

      current_token_sign_file = YAML.load_file(todays_datafile)

      { "Token" => current_token_sign_file["token"], "Sign" => current_token_sign_file["sign"], "Cuit" => cuit }
    end
  end
end
