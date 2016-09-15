module Snoopy
  class Bill
    include AuthData

    attr_reader :base_imp, :total

    attr_accessor :neto_total, :numero_documento, :condicion_iva_receptor, :tipo_documento, :concepto, :moneda,
                  :due_date, :aliciva_id, :fecha_servicio_desde, :fecha_servicio_hasta, :body,
                  :response, :cbte_asoc_num, :cbte_asoc_pto_venta, :numero, :alicivas,
                  :pkey, :cert, :cuit, :punto_venta, :condicion_iva_emisor, :auth, :errors,
                  :cae, :resultado, :fecha_proceso, :vencimiento_cae, :fecha_comprobante,
                  :observaciones, :events

    def initialize(attrs={})
      @pkey                   = attrs[:pkey]
      @cert                   = attrs[:cert]
      @cuit                   = attrs[:cuit]
      @punto_venta            = attrs[:sale_point]
      @condicion_iva_emisor   = attrs[:own_iva_cond]
      @neto_total             = attrs[:net]       || 0
      @tipo_documento         = attrs[:documento] || Snoopy.default_documento
      @moneda                 = attrs[:moneda]    || Snoopy.default_moneda
      @concepto               = attrs[:concepto]  || Snoopy.default_concepto
      @numero_documento       = attrs[:doc_num]
      @fecha_servicio_desde   = attrs[:fch_serv_desde]
      @fecha_servicio_hasta   = attrs[:fch_serv_hasta]
      @cbte_asoc_pto_venta    = attrs[:cbte_asoc_pto_venta] # Esto es el punto de venta de la factura para la nota de credito
      @cbte_asoc_num          = attrs[:cbte_asoc_num]       # Esto es el numero de factura para la nota de credito
      @condicion_iva_receptor = attrs[:iva_cond]
      @alicivas               = attrs[:alicivas]
      @response               = nil
      @errors                 = []
      @observaciones          = []
      @events                 = []
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
      @total = neto_total.zero? ? 0 : (neto_total + iva_sum).round(2)
    end

    def iva_sum
      @iva_sum = alicivas.collect{|aliciva| aliciva[:importe] }.sum.to_f.round_with_precision(2)
    end

    def cbte_type
      Snoopy::BILL_TYPE[condicion_iva_receptor.to_sym] || raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
    end

    def client
      Savon.client( :wsdl => Snoopy.service_url,
                    :ssl_cert_key_file => pkey,
                    :ssl_cert_file => cert,
                    :ssl_version => :TLSv1,
                    :read_timeout => 90,
                    :open_timeout => 90,
                    :headers => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
                    :pretty_print_xml => true,
                    :namespaces => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"} )
    end

    def set_bill_number!
      resp = client.call( :fe_comp_ultimo_autorizado,
                          :message => { "Auth" => generate_auth_file, "PtoVta" => punto_venta, "CbteTipo" => cbte_type })

      resp_errors = resp.hash[:envelope][:body][:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
      resp_errors.each_value { |value| @errors << "Código #{value[:code]}: #{value[:msg]}" } unless resp_errors.nil?
      @numero = resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 if @errors.empty?
    end

    def build_body_request
      today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')

      fecaereq = {"FeCAEReq" => {
                    "FeCabReq" => build_header,
                    "FeDetReq" => {
                      "FECAEDetRequest" => {
                        "Concepto"    => Snoopy::CONCEPTOS[concepto],
                        "DocTipo"     => Snoopy::DOCUMENTOS[tipo_documento],
                        "CbteFch"     => today,
                        "ImpTotConc"  => 0.00,
                        "MonId"       => Snoopy::MONEDAS[moneda][:codigo],
                        "MonCotiz"    => exchange_rate,
                        "ImpOpEx"     => 0.00,
                        "ImpTrib"     => 0.00 }}}}

      unless condicion_iva_emisor == :responsable_monotributo
        _alicivas = alicivas.collect do |aliciva|
          { "Id"      => Snoopy::ALIC_IVA[aliciva[:id]],
            "BaseImp" => aliciva[:base_imp],
            "Importe" => aliciva[:importe] }
        end
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = { "AlicIva" => _alicivas }
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = numero_documento
      detail["ImpNeto"]   = neto_total.to_f
      detail["ImpIVA"]    = iva_sum
      detail["ImpTotal"]  = total

      detail["CbteDesde"] = detail["CbteHasta"] = numero

      unless concepto == "Productos"
        detail.merge!({ "FchServDesde" => fecha_servicio_desde || today,
                        "FchServHasta" => fecha_servicio_hasta || today,
                        "FchVtoPago"   => due_date       || today})
      end

      if self.condicion_iva_receptor.to_s.include?("nota_credito")
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro"    => cbte_asoc_num,
                                                      "PtoVta" => cbte_asoc_pto_venta,
                                                      "Tipo"   => cbte_type }}})
      end

      @body = { "Auth" => generate_auth_file }.merge!(fecaereq)
    end

    def cae_request
      begin
        set_bill_number!
        if @errors.empty?
          build_body_request
          @response = client.call( :fecae_solicitar, :message => body ).body
          parse_response
        end
      rescue => e #Curl::Err::GotNothingError, Curl::Err::TimeoutError
        @errors = e.message
      end
      !@response.nil?
    end

    def aprobada?; @resultado == "A"; end
    def parcial?; @resultado == "P"; end
    def rechazada?; @resultado == "R"; end

    def parse_response
      result = { :errors => [], :observations => [], :events => [] }

      fecae_response = @response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_det_resp][:fecae_det_response] rescue {}
      fe_cab_resp    = @response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_cab_resp] rescue {}
      fecae_result   = @response[:fecae_solicitar_response][:fecae_solicitar_result] rescue {}

      @cae               = fecae_response[:cae]
      @resultado         = fecae_response[:resultado]
      @numero            = fecae_response[:cbte_desde]
      @fecha_proceso     = fe_cab_resp[:fch_proceso]
      @vencimiento_cae   = fecae_response[:cae_fch_vto]
      @fecha_comprobante = fecae_response[:cbte_fch]

      if fecae_response.has_key? :observaciones
        begin
          fecae_response.delete(:observaciones).each_value do |obs|
            [obs].flatten.each { |ob| @observaciones << "Código #{ob[:code]}: #{ob[:msg]}" }
          end
        rescue
          @observaciones << "Ocurrió un error al parsear las observaciones de AFIP"
        end
      end

      if fecae_result.has_key? :errors
        begin
          fecae_result[:errors].each_value do |errores|
            [errores].flatten.each { |error| @errors << "Código #{error[:code]}: #{error[:msg]}" }
          end
        rescue
          @errors << "Ocurrió un error al parsear los errores de AFIP"
        end
      end

      if fecae_result.has_key? :events
        begin
          fecae_result[:events].each_value do |events|
            [events].flatten.each { |event| @events << "Código #{event[:code]}: #{event[:msg]}" }
          end
        rescue
          @events << "Ocurrió un error al parsear los eventos de AFIP"
        end
      end
    end

    def build_header
      { "CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => punto_venta }
    end

    def self.bill_request(numero, attrs={})
      bill = new(attrs)
      begin
        response = bill.client.call( :fe_comp_consultar,
                                     :message => {"Auth" => bill.generate_auth_file,
                                                  "FeCompConsReq" => {"CbteTipo" => bill.cbte_type, "PtoVta" => bill.punto_venta, "CbteNro" => numero.to_s}})
        {:bill => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:result_get], :errors => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:errors]}
      rescue => e
        response = { :errors => e.message }
      end
    end

  end
end
