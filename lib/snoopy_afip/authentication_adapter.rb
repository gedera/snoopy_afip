# coding: utf-8
module Snoopy
  class AuthenticationAdapter
    attr_reader :id, :from, :to, :pkey, :cert, :tra, :cms, :request, :response, :client

    def initialize(attrs={})
      time = Time.new
      @id     = time.to_i
      @from   = time.strftime("%Y-%m-%dT%H:%M:%S%:z")
      @to     = (time + 86400/2).strftime("%Y-%m-%dT%H:%M:%S%:z") # 86400.seg = 1.day
      @pkey   = attrs[:pkey]
      @cert   = attrs[:cert]
      @client = Snoopy::Client.new(client_configuration)
    end

    # http://www.afip.gov.ar/ws/WSAA/Especificacion_Tecnica_WSAA_1.2.0.pdf
    # coe.notAuthorized:          Computador no autorizado a acceder los servicio de AFIP
    # cms.bad:                    El CMS no es valido
    # cms.bad.base64:             No se puede decodificar el BASE64
    # cms.cert.notFound:          No se ha encontrado certificado de firma en el CMS
    # cms.sign.invalid:           Firma inválida o algoritmo no soportado
    # cms.cert.expired:           Certificado expirado
    # cms.cert.invalid:           Certificado con fecha de generación posterior a la actual
    # cms.cert.untrusted:         Certificado no emitido por AC de confianza
    # xml.bad:                    No se ha podido interpretar el XML contra el SCHEMA
    # xml.source.invalid:         El atributo 'source' no se corresponde con el DN del Certificad
    # xml.destination.invalid:    El atributo 'destination' no se corresponde con el DN del WSAA
    # xml.version.notSupported:   La versión del documento no es soportada
    # xml.generationTime.invalid: El tiempo de generación es posterior a la hora actual o posee más de 24 horas de antiguedad
    # xml.expirationTime.expired: El tiempo de expiración es inferior a la hora actual
    # xml.expirationTime.invalid: El tiempo de expiración del documento es superior a 24 horas
    # wsn.unavailable:            El servicio al que se desea acceder se encuentra momentáneamente fuera de servicio
    # wsn.notFound:               Servicio informado inexistente
    # wsaa.unavailable:           El servicio de autenticación/autorización se encuentra momentáneamente fuera de servicio
    # wsaa.internalError:         No se ha podido procesar el requerimiento
    def authenticate!
      @response = client.call(:login_cms, :message => { :in0 => build_cms })
      parser_response.deep_symbolize_keys
    end

    def parser_response
      response_credentials.merge( 'expiration_time' => response_header["expirationTime"] )
    end

    def response_header
      @_header_response ||= response_to_hash["loginTicketResponse"]["header"]
    end

    def response_credentials
      @_credentials ||= response_to_hash["loginTicketResponse"]["credentials"]
    end

    def response_to_hash
      @_response_to_hash ||= Nori.new.parse(response[:login_cms_response][:login_cms_return])
    end

    def self.generate_pkey(leng=8192)
      begin
        OpenSSL::PKey::RSA.new(leng).to_pem # %x(openssl genrsa 8192)
      rescue => e
        raise "command fail: 'openssl genrsa 8192' error al generar pkey: #{e.message}, error: #{e.message}"
      end
    end

    def self.generate_certificate_request_with_ruby(pkey, subj_o, subj_cn, subj_cuit)
      options = [ ['C',             'AR',                OpenSSL::ASN1::PRINTABLESTRING],
                  ['O',             subj_o,              OpenSSL::ASN1::UTF8STRING],
                  ['CN',            subj_cn,             OpenSSL::ASN1::UTF8STRING],
                  ['serialNumber',  "CUIT #{subj_cuit}", OpenSSL::ASN1::UTF8STRING] ]
      key = OpenSSL::PKey::RSA.new(File.read(pkey))

      request = OpenSSL::X509::Request.new
      request.version = 0
      request.subject = OpenSSL::X509::Name.new(options)
      request.public_key = key.public_key
      request.sign(key, OpenSSL::Digest::SHA256.new).to_pem
    end

    # pkey:      clave privada generada por el metodo generate_pkey.
    # subj_o:    Nombre de la empresa, registrado en AFIP.
    # subj_cn:   hostname del servidor que realizara la comunicación con AFIP.
    # subj_cuit: Cuit registado en AFIP.
    def self.generate_certificate_request_with_bash(pkey, subj_o, subj_cn, subj_cuit)
      begin
        %x(openssl req -new -key #{pkey} -subj "/C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit}")
      rescue => e
        raise "command fail: openssl req -new -key #{pkey} -subj /C=AR/O=#{subj_o}/CN=#{subj_cn}/serialNumber=CUIT #{subj_cuit} -out #{out_path}, error: #{e.message}"
      end
    end

    def build_tra
      builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.loginTicketRequest('version' => '1.0') {
          xml.header {
            xml.uniqueId id
            xml.generationTime from
            xml.expirationTime to
          }
          xml.service "wsfe"
        }
      end
      builder.to_xml
    end

    def build_cms
      key = OpenSSL::PKey::RSA.new(File.read(pkey))
      crt = OpenSSL::X509::Certificate.new(File.read(cert))
      pkcs7 = OpenSSL::PKCS7::sign(crt, key, build_tra)
      @cms = pkcs7.to_pem.lines.to_a[1..-2].join
    rescue => e
      raise Snoopy::Exception::AuthenticationAdapter::CmsBuilder.new(e.message, e.backtrace)
    end

    def client_configuration
      { :wsdl             => Snoopy.auth_url,
        :ssl_version      => :TLSv1,
        :pretty_print_xml => true }
    end
  end
end

