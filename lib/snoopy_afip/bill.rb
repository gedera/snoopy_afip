module Snoopy
  class Bill
    attr_reader :client, :base_imp, :total, :errors
    attr_accessor :net, :doc_num, :iva_cond, :documento, :concepto, :moneda,
                  :due_date, :aliciva_id, :fch_serv_desde, :fch_serv_hasta,
                  :body, :response, :cbte_asoc_num, :cbte_asoc_pto_venta, :bill_number

    def initialize(attrs = {})
      Snoopy::AuthData.fetch
      @client  = Savon.client(
        :wsdl => Snoopy.service_url,
        :ssl_cert_key_file => Snoopy.pkey,
        :ssl_cert_file => Snoopy.cert,
        :ssl_verify_mode => :none,
        :read_timeout => 90,
        :open_timeout => 90,
        :headers => { "Accept-Encoding" => "gzip, deflate", "Connection" => "Keep-Alive" },
        :pretty_print_xml => true,
        :namespaces => {"xmlns" => "http://ar.gov.afip.dif.FEV1/"}
      )
      @body           = {"Auth" => Snoopy.auth_hash}
      @net            = attrs[:net] || 0
      self.documento  = attrs[:documento] || Snoopy.default_documento
      self.moneda     = attrs[:moneda]    || Snoopy.default_moneda
      self.iva_cond   = attrs[:iva_cond]
      self.concepto   = attrs[:concepto]  || Snoopy.default_concepto
      @errors = []
    end

    def cbte_type
      if Snoopy.own_iva_cond == :responsable_monotributo
        "11"
      else
        Snoopy::BILL_TYPE[iva_cond.to_sym] ||
        raise(NullOrInvalidAttribute.new, "Please choose a valid document type.")
      end
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
      @iva_sum = net * Snoopy::ALIC_IVA[aliciva_id][1]
      @iva_sum.round_with_precision(2)
    end

    def cae_request
      response = client.call(:fecae_solicitar,
                             :message => body)
      response
    end

    def setup_bill
      today = Time.new.in_time_zone('Buenos Aires').strftime('%Y%m%d')

      fecaereq = {"FeCAEReq" => {
                    "FeCabReq" => Snoopy::Bill.header(cbte_type),
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
      unless Snoopy.own_iva_cond == :responsable_monotributo
        fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]["Iva"] = {"AlicIva" => {
                                                                        "Id" => Snoopy::ALIC_IVA[aliciva_id][0],
                                                                        "BaseImp" => net,
                                                                        "Importe" => iva_sum}}
      end

      detail = fecaereq["FeCAEReq"]["FeDetReq"]["FECAEDetRequest"]

      detail["DocNro"]    = doc_num
      detail["ImpNeto"]   = net.to_f
      detail["ImpIVA"]    = iva_sum
      detail["ImpTotal"]  = total

      detail["CbteDesde"] = detail["CbteHasta"] = bill_number

      unless concepto == "Productos"
        detail.merge!({"FchServDesde" => fch_serv_desde || today,
                      "FchServHasta"  => fch_serv_hasta || today,
                      "FchVtoPago"    => due_date       || today})
      end

      if self.iva_cond == :nota_credito_a or self.iva_cond == :nota_credito_b
        detail.merge!({"CbtesAsoc" => {"CbteAsoc" => {"Nro" => cbte_asoc_num,
                                                      "PtoVta" => cbte_asoc_pto_venta,
                                                      "Tipo" => self.iva_cond == :nota_credito_a ? Snoopy::BILL_TYPE[:responsable_inscripto] : Snoopy::BILL_TYPE[:consumidor_final] }}})
      end

      body.merge!(fecaereq)
      true
    end

    def bill_request bill_number, bill_type = cbte_type, sale_point = Snoopy.sale_point
      response = client.call( :fe_comp_consultar,
                              :message => {"Auth" => Snoopy.auth_hash, "FeCompConsReq" => {"CbteTipo" => bill_type, "PtoVta" => sale_point, "CbteNro" => bill_number.to_s}})
      {:bill => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:result_get], :errors => response.to_hash[:fe_comp_consultar_response][:fe_comp_consultar_result][:errors]}
    end

    def next_bill_number
      begin
        resp = client.call(:fe_comp_ultimo_autorizado,
                           :message => {"Auth" => Snoopy.auth_hash, "PtoVta" => Snoopy.sale_point, "CbteTipo" => cbte_type})
        resp_errors = resp.hash[:envelope][:body][:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:errors]
        unless resp_errors.nil?
          resp_errors.each_value do |value|
            errors << "Código #{value[:code]}: #{value[:msg]}"
          end
        end
      rescue #Curl::Err::GotNothingError, Curl::Err::TimeoutError
         errors << "Error de conexión con webservice de AFIP. Intente mas tarde."
      end
      result = {:errors => errors}
      result[:bill_number] = errors.empty? ? resp.to_hash[:fe_comp_ultimo_autorizado_response][:fe_comp_ultimo_autorizado_result][:cbte_nro].to_i + 1 : -1
      result
    end

    class << self
      def header(cbte_type)#todo sacado de la factura
        {"CantReg" => "1", "CbteTipo" => cbte_type, "PtoVta" => Snoopy.sale_point}
      end
    end

    def parse_response(response)
      result = {:errors => [], :observations => []}

      result[:fecae_response] = response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_det_resp][:fecae_det_response] rescue {}

      if result[:fecae_response].has_key? :observaciones
        begin
          result[:fecae_response][:observaciones].each_value do |obs|
            result[:observations] << "Código #{obs[:code]}: #{obs[:msg]}"
          end
        rescue
          result[:observations] << "Ocurrió un error al parsear las observaciones de AFIP"
        end
      end

      fecae_result = response[:fecae_solicitar_response][:fecae_solicitar_result] rescue {}

      if fecae_result.has_key? :errors
        begin
          fecae_result[:errors].each_value do |error|
            result[:errors] << "Código #{error[:code]}: #{error[:msg]}"
          end
        rescue
          result[:errors] << "Ocurrió un error al parsear los errores de AFIP"
        end
      end

      fe_cab_resp = response[:fecae_solicitar_response][:fecae_solicitar_result][:fe_cab_resp] rescue {}
      result[:fecae_response].merge!(fe_cab_resp)

      result
    end
  end
end
