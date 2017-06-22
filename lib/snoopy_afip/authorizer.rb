# coding: utf-8
module Snoopy
  class Authorizer
    attr_reader :id, :from, :to, :pkey, :cert, :tra, :cms, :request, :response

    def initialize(attrs)
      @id = Time.new.to_i
      @from = "2017-06-22T00:00:00-03:00"|| attrs[:from].to_time.strftime("%Y-%m-%dT00:00:00%z") # FROM = $(date "+%Y-%m-%dT00:00:00-03:00")
      @to = "2017-06-22T23:59:59-03:00" || attrs[:to].to_time.strftime("%Y-%m-%dT23:59:59%z")      # TO = $(date "+%Y-%m-%dT23:59:59-03:00")
      @pkey = attrs[:pkey] || "/home/gabriel/src/wispro/services/argentina_invoice_service/certs/testing_pkey"
      @cert = attrs[:cert] || "/home/gabriel/src/wispro/services/argentina_invoice_service/certs/testing_cert.crt"
    end

    def authorize
      call
      parser_response
    end

    def client
      Savon.client( :wsdl             => Snoopy.auth_url,
                    :ssl_version      => :TLSv1,
                    :pretty_print_xml => true )
    end

    def call
      @response = client.call(:login_cms, :message => { :in0 => build_cms })
    end

    def parser_response
      Nori.new.parse(response.body[:login_cms_response][:login_cms_return])["loginTicketResponse"]["credentials"]
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

    def self.generate_pkey
      begin
        OpenSSL::PKey::RSA.new(8192).to_pem # %x(openssl genrsa 8192)
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
  end
end

