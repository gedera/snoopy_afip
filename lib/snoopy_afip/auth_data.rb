module Snoopy
  module AuthData
    def generate_auth_file
      Snoopy::AuthData.generate_auth_file(:cuit => cuit, :pkey => pkey, :cert => cert)

      todays_datafile = "/tmp/snoopy_afip_#{cuit}_#{Time.new.strftime('%d_%m_%Y')}.yml"
      current_token_sign_file = YAML.load_file(todays_datafile)

      { "Token" => current_token_sign_file["token"], "Sign" => current_token_sign_file["sign"], "Cuit" => cuit }
    end

    def self.generate_auth_file invoicing_firm
      raise "Debe definir el cuit del emisor"                   unless invoicing_firm[:cuit]
      raise "Archivo de llave privada no encontrado en #{pkey}" unless File.exists?(invoicing_firm[:pkey])
      raise "Archivo certificado no encontrado en #{cert}"      unless File.exists?(invoicing_firm[:cert])

      todays_datafile = "/tmp/snoopy_afip_#{invoicing_firm[:cuit]}_#{Time.new.strftime('%d_%m_%Y')}.yml"
      opts = "-u #{Snoopy.auth_url} -k #{invoicing_firm[:pkey]} -c #{invoicing_firm[:cert]} -i #{invoicing_firm[:cuit]}"

      %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh #{opts}) unless File.exists?(todays_datafile)
    end

    def self.generate_pkey file
      begin
        %x(openssl genrsa -out #{file} 2048)
      rescue => e
        raise "command 'openssl genrsa -out #{file} 1024' error al generar pkey: #{e.message}"
      end
    end
  end
end
