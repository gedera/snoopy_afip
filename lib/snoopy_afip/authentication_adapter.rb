# coding: utf-8
module Snoopy
  class AuthenticationAdapter
    attr_reader :id, :from, :to, :pkey, :cert, :tra, :cms, :request, :response

    def initialize(attrs={})
      time = Time.new
      @id   = time.to_i
      @from = time.strftime("%Y-%m-%dT%H:%M:%S%:z")
      @to   = (time + 86400/2).strftime("%Y-%m-%dT%H:%M:%S%:z") # 86400.seg = 1.day
      @pkey = attrs[:pkey]
      @cert = attrs[:cert]
    end

    def autenticate!
      @response = call
      parser_response
    end

    def call
      begin
        Timeout::timeout(5) do
          client.call(:login_cms, :message => { :in0 => build_cms }).body
        end
      rescue Timeout::Error
        raise Snoopy::Exception::AuthenticationAdapter::ServerTimeout.new
      rescue => e
        raise Snoopy::Exception::AuthenticationAdapter::ClientError.new(e)
      end
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
      @_response_to_hash ||= Nori.new.parse(response.body[:login_cms_response][:login_cms_return])
    end

    def self.generate_pkey
      begin
        OpenSSL::PKey::RSA.new(8192).to_pem # %x(openssl genrsa 8192)
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
      request.sign(key, OpenSSL::Digest::SHA256.new)
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

    def client
      Savon.client( :wsdl             => Snoopy.auth_url,
                    :ssl_version      => :TLSv1,
                    :pretty_print_xml => true )
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
    end
  end
end

