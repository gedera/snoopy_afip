module Snoopy
  class Bill
    include AuthData

    attr_reader :base_imp, :total, :errors

    attr_accessor :net, :doc_num, :iva_cond, :documento, :concepto, :moneda,
                  :due_date, :aliciva_id, :fch_serv_desde, :fch_serv_hasta, :body,
                  :response, :cbte_asoc_num, :cbte_asoc_pto_venta, :bill_number, :alicivas,
                  :pkey, :cert, :cuit, :sale_point, :own_iva_cond, :auth, :response

    def initialize(attrs={})
      @pkey                = attrs[:pkey]
      @cert                = attrs[:cert]
      @cuit                = attrs[:cuit]
      @sale_point          = attrs[:sale_point]
      @own_iva_cond        = attrs[:own_iva_cond]
      @net                 = attrs[:net]       || 0
      @documento           = attrs[:documento] || Snoopy.default_documento
      @moneda              = attrs[:moneda]    || Snoopy.default_moneda
      @concepto            = attrs[:concepto]  || Snoopy.default_concepto
      @doc_num             = attrs[:doc_num]
      @fch_serv_desde      = attrs[:fch_serv_desde]
      @fch_serv_hasta      = attrs[:fch_serv_hasta]
      @cbte_asoc_pto_venta = attrs[:cbte_asoc_pto_venta] # Esto es el punto de venta de la factura para la nota de credito
      @cbte_asoc_num       = attrs[:cbte_asoc_num]       # Esto es el numero de factura para la nota de credito
      @iva_cond            = attrs[:iva_cond]
      @alicivas            = attrs[:alicivas]
      @errors = []
    end

    def exchange_rate
      return 1 if moneda == :peso
      response = client.fe_param_get_cotizacion do |soap|
        soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
        soap.body = body.merge!({"MonId" => Snoopy::MONEDAS[moneda][:codigo]})
      end
      response.to_hash[:fe_param_get_cotizacion_response][:fe_param_get_cotizacion_result][:result_get][:mon_cotiz].to_f
    end

    def total
      @total = net.zero? ? 0 : (net + iva_sum).round(2)
    end

    def iva_sum
      @iva_sum = alicivas.collect{|aliciva| aliciva[:importe] }.sum.to_f.round_with_precision(2)
    end

    def cbte_type
      Snoopy::BILL_TYPE[iva_cond.to_sym] || raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
    end

    def client
      @client ||= Savon.client( :wsdl => Snoopy.service_url,
                                :ssl_cert_key_file => pkey,
                                :ssl_cert_file => cert,
                                :ssl_version => :TLSv1,
                                :read_timeout => 90,
                                :open_timeout => 90,
                                :headers => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
                                :pretty_print_xml => true,
                                :namespaces => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"} )
    end

    def set_bill_number
      begin
        resp = client.call( :fe_comp_ultimo_autorizado,
                            :message => { "Auth" => generate_auth_file, "PtoVta" => sale_point, "CbteTipo" => cbte_type })

        resp_errors = resp.hash[:envelope][:body][:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
        resp_errors.each_value { |value| errors << "Código #{value[:code]}: #{value[:msg]}" } unless resp_errors.nil?
        @bill_number = resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 if errors.empty?
      rescue => e #Curl::Err::GotNothingError, Curl::Err::TimeoutError
        errors << e.message
      end
      { :numero_factura => bill_number, :errors => errors }
    end

    def build_body_request
      today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')

      fecaereq = {"FeCAEReq" => {
                    "FeCabReq" => build_header,
                    "FeDetReq" => {
                      "FECAEDetRequest" => {
                        "Concepto"    => Snoopy::CONCEPTOS[concepto],
                        "DocTipo"     => Snoopy::DOCUMENTOS[documento],
                        "CbteFch"     => today,
                        "ImpTotConc"  => 0.00,
                        "MonId"       => Snoopy::MONEDAS[moneda][:codigo],
                        "MonCotiz"    => exchange_rate,
                        "ImpOpEx"     => 0.00,
                        "ImpTrib"     => 0.00 }}}}

      unless own_iva_cond == :responsable_monotributo
        _alicivas = alicivas.collect do |aliciva|
          { "Id"      => Snoopy::ALIC_IVA[aliciva[:id]],
            "BaseImp" => aliciva[:base_imp],
            "Importe" => aliciva[:importe] }
        end
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = { "AlicIva" => _alicivas }
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = doc_num
      detail["ImpNeto"]   = net.to_f
      detail["ImpIVA"]    = iva_sum
      detail["ImpTotal"]  = total

      detail["CbteDesde"] = detail["CbteHasta"] = bill_number

      unless concepto == "Productos"
        detail.merge!({ "FchServDesde" => fch_serv_desde || today,
                        "FchServHasta" => fch_serv_hasta || today,
                        "FchVtoPago"   => due_date       || today})
      end

      if self.iva_cond.to_s.include?("nota_credito")
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro"    => cbte_asoc_num,
                                                      "PtoVta" => cbte_asoc_pto_venta,
                                                      "Tipo"   => cbte_type }}})
      end

      @body = { "Auth" => generate_auth_file }.merge!(fecaereq)
    end

    def cae_request
      @response = set_bill_number
      if @response[:errors].empty?
        begin
          build_body_request
          resp = client.call( :fecae_solicitar, :message => body )
          @response = parse_response(resp.body)
        rescue => e
          @response = { :errors => e.message, :observations => [], :events => [] }
        end
      end
      @response
    end

    def aprobada?
     @response and @response[:fecae_response][:resultado] == "A"
    end

    def rechazada?
      @response and @response[:fecae_response][:resultado] == "R"
    end

    def parcial?
      @response and @response[:fecae_response][:resultado] == "P"
    end

    def parse_response(response)
      result = { :errors => [], :observations => [], :events => [] }

      result[:fecae_response] = response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_det_resp][:fecae_det_response] rescue {}

      if result[:fecae_response].has_key? :observaciones
        begin
          result[:fecae_response].delete(:observaciones).each_value do |obs|
            [obs].flatten.each { |ob| result[:observations] << "Código #{ob[:code]}: #{ob[:msg]}" }
          end
        rescue
          result[:observations] << "Ocurrió un error al parsear las observaciones de AFIP"
        end
      end

      fecae_result = response[:fecae_solicitar_response][:fecae_solicitar_result] rescue {}

      if fecae_result.has_key? :errors
        begin
          fecae_result[:errors].each_value do |errors|
            [errors].flatten.each { |error| result[:errors] << "Código #{error[:code]}: #{error[:msg]}" }
          end
        rescue
          result[:errors] << "Ocurrió un error al parsear los errores de AFIP"
        end
      end

      if fecae_result.has_key? :events
        begin
          fecae_result[:events].each_value do |events|
            [events].flatten.each { |event| result[:events] << "Código #{event[:code]}: #{event[:msg]}" }
          end
        rescue
          result[:events] << "Ocurrió un error al parsear los eventos de AFIP"
        end
      end

      fe_cab_resp = response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_cab_resp] rescue {}
      result[:fecae_response].merge!(fe_cab_resp) unless fe_cab_resp.nil?

      result
    end

    def build_header
      { "CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => sale_point }
    end

    def self.bill_request(bill_number, attrs={})
      bill = new(attrs)
      begin
        response = bill.client.call( :fe_comp_consultar,
                                     :message => {"Auth" => bill.generate_auth_file,
                                                  "FeCompConsReq" => {"CbteTipo" => bill.cbte_type, "PtoVta" => bill.sale_point, "CbteNro" => bill_number.to_s}})
        {:bill => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:result_get], :errors => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:errors]}
      rescue => e
        response = { :errors => e.message }
      end
    end

  end
end
