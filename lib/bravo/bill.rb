module Bravo
  class Bill
    attr_reader :client, :base_imp, :total, :errors
    attr_accessor :net, :doc_num, :iva_cond, :documento, :concepto, :moneda,
                  :due_date, :aliciva_id, :fch_serv_desde, :fch_serv_hasta,
                  :body, :response, :cbte_asoc_num, :cbte_asoc_pto_venta

    def initialize(attrs = {})
      Bravo::AuthData.fetch
      @client         = Savon::Client.new do
        wsdl.document = Bravo.service_url
        http.auth.ssl.cert_key_file = Bravo.pkey
        http.auth.ssl.cert_file = Bravo.cert
        http.auth.ssl.verify_mode = :none
        http.read_timeout = 90
        http.open_timeout = 90
        http.headers = { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" }
        config.pretty_print_xml = true
      end
      @body           = {"Auth" => Bravo.auth_hash}
      @net            = attrs[:net] || 0
      self.documento  = attrs[:documento] || Bravo.default_documento
      self.moneda     = attrs[:moneda]    || Bravo.default_moneda
      self.iva_cond   = attrs[:iva_cond]
      self.concepto   = attrs[:concepto]  || Bravo.default_concepto
      @errors = []
    end

    def cbte_type
      if Bravo.own_iva_cond == :responsable_monotributo
        "11"
      else
        Bravo::BILL_TYPE[iva_cond.to_sym] ||
        raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
      end
    end

    def exchange_rate
      return 1 if moneda == :peso
      response = client.fe_param_get_cotizacion do |soap|
        soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
        soap.body = body.merge!({"MonId" => Bravo::MONEDAS[moneda][:codigo]})
      end
      response.to_hash[:fe_param_get_cotizacion_response][:fe_param_get_cotizacion_result][:result_get][:mon_cotiz].to_f
    end

    def total
      @total = net.zero? ? 0 : (net + iva_sum).round(2)
    end

    def iva_sum
      @iva_sum = net * Bravo::ALIC_IVA[aliciva_id][1]
      @iva_sum.round_with_precision(2)
    end

    def authorize
      return false unless setup_bill
      response = client.request :fecae_solicitar do |soap|
        soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
        soap.body = body
      end
      setup_response(response.to_hash)
    end

    def setup_bill
      today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')

      fecaereq = {"FeCAEReq" => {
                    "FeCabReq" => Bravo::Bill.header(cbte_type),
                    "FeDetReq" => {
                      "FECAEDetRequest" => {
                        "Concepto"    => Bravo::CONCEPTOS[concepto],
                        "DocTipo"     => Bravo::DOCUMENTOS[documento],
                        "CbteFch"     => today,
                        "ImpTotConc"  => 0.00,
                        "MonId"       => Bravo::MONEDAS[moneda][:codigo],
                        "MonCotiz"    => exchange_rate,
                        "ImpOpEx"     => 0.00,
                        "ImpTrib"     => 0.00 }}}}
      unless Bravo.own_iva_cond == :responsable_monotributo
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = {"AlicIva" => {
                                                                        "Id" => Bravo::ALIC_IVA[aliciva_id][0],
                                                                        "BaseImp" => net,
                                                                        "Importe" => iva_sum}}
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = doc_num
      detail["ImpNeto"]   = net.to_f
      detail["ImpIVA"]    = iva_sum
      detail["ImpTotal"]  = total

      if bill_number = next_bill_number
        detail["CbteDesde"] = detail["CbteHasta"] = bill_number
      else
        return false
      end

      unless concepto == "Productos"
        detail.merge!({"FchServDesde" => fch_serv_desde || today,
                      "FchServHasta"  => fch_serv_hasta || today,
                      "FchVtoPago"    => due_date       || today})
      end

      if self.iva_cond == :nota_credito_a or self.iva_cond == :nota_credito_b
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro" => cbte_asoc_num,
                                                      "PtoVta" => cbte_asoc_pto_venta,
                                                      "Tipo" => self.iva_cond == :nota_credito_a ? Bravo::BILL_TYPE[:responsable_inscripto] : Bravo::BILL_TYPE[:consumidor_final] }}})
      end

      body.merge!(fecaereq)
      true
    end

    def next_bill_number
      begin
        resp = client.request :fe_comp_ultimo_autorizado do
          soap.namespaces["xmlns"] = "http://ar.gov.afip.dif.FEV1/"
          soap.body = {"Auth" => Bravo.auth_hash, "PtoVta" => Bravo.sale_point, "CbteTipo" => cbte_type}
        end
        resp_errors = resp.hash[:envelope][:body][:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
        unless resp_errors.nil?
          resp_errors.each_value do |value|
            errors << "Código #{value[:code]}: #{value[:msg]}"
          end
        end
      rescue Curl::Err::GotNothingError, Curl::Err::TimeoutError
         errors << "Error de conexión con webservice de AFIP. Intente mas tarde."
      end
        errors.empty? ? resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 : nil
    end

    private

    class << self
      def header(cbte_type)#todo sacado de la factura
        {"CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => Bravo.sale_point}
      end
    end

    def setup_response(response)
      begin
        result = response[:fecae_solicitar_response][:fecae_solicitar_result]

        unless result[:fe_cab_resp][:resultado] == "A"
          result[:fe_det_resp][:fecae_det_response][:observaciones].each_value do |obs|
            errors << "Código #{obs[:code]}: #{obs[:msg]}"
          end
          return false
        end

        response_header = result[:fe_cab_resp]
        response_detail = result[:fe_det_resp][:fecae_det_response]

        request_header  = body["FeCAEReq"]["FeCabReq"].underscore_keys.symbolize_keys
        request_detail  = body["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"].underscore_keys.symbolize_keys
      rescue NoMethodError
        if defined?(RAILS_DEFAULT_LOGGER) && logger = RAILS_DEFAULT_LOGGER
          logger.error "[BRAVO] NoMethodError: Response #{response}"
        else
          puts "[BRAVO] NoMethodError: Response #{response}"
        end
        return false
      end

      response_hash = {}
      unless Bravo.own_iva_cond == :responsable_monotributo
        iva = request_detail.delete(:iva)["AlicIva"].underscore_keys.symbolize_keys
        request_detail.merge!(iva)
        response_hash.merge!({
          :iva_id        => request_detail.delete(:id),
          :iva_importe   => request_detail.delete(:importe),
          :iva_base_imp  => request_detail.delete(:base_imp),
        })
      end

      response_hash.merge!({ :header_result => response_header.delete(:resultado),
                             :authorized_on => response_header.delete(:fch_proceso),
                             :detail_result => response_detail.delete(:resultado),
                             :cae_due_date  => response_detail.delete(:cae_fch_vto),
                             :cae           => response_detail.delete(:cae),
                             :moneda        => request_detail.delete(:mon_id),
                             :cotizacion    => request_detail.delete(:mon_cotiz),
                             :doc_num       => request_detail.delete(:doc_nro)
                            }).merge!(request_header).merge!(request_detail)

      keys, values  = response_hash.to_a.transpose
      self.response = (defined?(Struct::Response) ? Struct::Response : Struct.new("Response", *keys)).new(*values)
    end
  end
end
