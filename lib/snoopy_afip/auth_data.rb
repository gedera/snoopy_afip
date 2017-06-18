# coding: utf-8
module Snoopy
  module AuthData
    def self.generate_auth_file(invoicing_firm)
      raise "Debe definir el cuit del emisor"                                    unless invoicing_firm[:cuit]
      raise "Archivo certificado no encontrado en #{invoicing_firm[:cert]}"      unless File.exists?(invoicing_firm[:cert])
      raise "Archivo de llave privada no encontrado en #{invoicing_firm[:pkey]}" unless File.exists?(invoicing_firm[:pkey])

      todays_datafile = "/tmp/snoopy_afip_#{invoicing_firm[:cuit]}_#{Date.today.strftime('%d_%m_%Y')}.yml"
      opts = "-u #{Snoopy.auth_url} -k #{invoicing_firm[:pkey]} -c #{invoicing_firm[:cert]} -i #{invoicing_firm[:cuit]}"

      %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh #{opts}) unless File.exists?(todays_datafile)
      raise AuthDataError.new unless File.exists?(todays_datafile)
      current_token_sign_file = YAML.load_file(todays_datafile)
      { "Token" => current_token_sign_file["token"], "Sign" => current_token_sign_file["sign"], "Cuit" => invoicing_firm[:cuit] }
    end

    def self.generate_pkey file
      begin
        %x(openssl genrsa -out #{file} 8192)
      rescue => e
        raise "command fail: 'openssl genrsa -out #{file} 8192' error al generar pkey: #{e.message}, error: #{e.message}"
      end
    end

    # pkey: clave privada generada por el metodo generate_pkey.
    # subj_o: Nombre de la empresa, registrado en AFIP.
    # subj_cn: hostname del servidor que realizara la comunicación con AFIP.
    # subj_cuit: Cuit registado en AFIP.
    # out_path: donde se almacenara el certificado generado.
    # Snoopy::AuthData.generate_certificate_request(generate_pkey, subj_o, subj_cn, subj_cuit, tmp_cert_req_path)
    def self.generate_certificate_request(pkey, subj_o, subj_cn, subj_cuit, out_path)
      begin
        %x(openssl req -new -key #{pkey} -subj "/C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit}" -out #{out_path})
      rescue => e
        raise "command fail: openssl req -new -key #{pkey} -subj /C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit} -out #{out_path}, error: #{e.message}"
      end
    end
  end
end
