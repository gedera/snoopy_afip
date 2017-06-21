# coding: utf-8
module Snoopy
  module AuthData
    def self.generate_pkey
      begin
        %x(openssl genrsa 8192)
      rescue => e
        raise "command fail: 'openssl genrsa 8192' error al generar pkey: #{e.message}, error: #{e.message}"
      end
    end

    # pkey:      clave privada generada por el metodo generate_pkey.
    # subj_o:    Nombre de la empresa, registrado en AFIP.
    # subj_cn:   hostname del servidor que realizara la comunicación con AFIP.
    # subj_cuit: Cuit registado en AFIP.
    def self.generate_certificate_request(pkey, subj_o, subj_cn, subj_cuit)
      begin
        %x(openssl req -new -key #{pkey} -subj "/C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit}")
      rescue => e
        raise "command fail: openssl req -new -key #{pkey} -subj /C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit} -out #{out_path}, error: #{e.message}"
      end
    end

    def self.current_token_sign_file(cuit)
      "/tmp/snoopy_afip_#{cuit}_#{Date.today.strftime('%d_%m_%Y')}.yml"
    end

    def self.generate_auth_file(cuit, pkey, cert)
      raise "Debe definir el cuit del emisor"                   unless cuit
      raise "Archivo certificado no encontrado en #{cert}"      unless File.exists? cert
      raise "Archivo de llave privada no encontrado en #{pkey}" unless File.exists? pkey

      todays_datafile = Snoopy::AuthData.current_token_sign_file(cuit)

      %x(#{File.dirname(__FILE__)}/../../wsaa-client.sh -u #{Snoopy.auth_url} -k #{pkey} -c #{cert} -i #{cuit}) unless File.exists?(todays_datafile)

      # Si no se creo el archivo todays_datafile es por que algo esta mal,
      # puede que este mal el certificado o el CUIT. La pkey no va estar mal por que la genero yo.
      # El tema es que revisando el XML que devuelve la AFIP solo dice ERROR pero no dice nada mas.
      File.exists?(todays_datafile)
    end
  end
end
