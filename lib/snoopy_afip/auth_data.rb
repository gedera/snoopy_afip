# coding: utf-8
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
    def generate_certificate_request(pkey, subj_o, subj_cn, subj_cuit, out_path)
      begin
        %x(openssl req -new -key #{pkey} -subj "/C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit}" -out #{out_path})
      rescue => e
        raise "command fail: openssl req -new -key #{pkey} -subj /C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit} -out #{out_path}, error: #{e.message}"
    end
  end
end
