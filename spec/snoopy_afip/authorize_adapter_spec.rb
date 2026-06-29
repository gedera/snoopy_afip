require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

RSpec.describe Snoopy::AuthorizeAdapter do
  subject(:adapter) do
    described_class.new(bill: nil, cuit: "20111111112", sign: "SIGN", token: "TOKEN",
                        pkey: "/tmp/pkey", cert: "/tmp/cert")
  end

  describe "#auth" do
    it "arma el hash de credenciales para AFIP" do
      expect(adapter.auth).to eq("Token" => "TOKEN", "Sign" => "SIGN", "Cuit" => "20111111112")
    end
  end

  # Regresión #10/#16: los rescues de parseo registraban con `errors << ...`
  # sobre un Hash (NoMethodError) y la línea 182 usaba una constante mal
  # namespaceada (NameError). Ahora registran en @errors un String (.message)
  # y NO propagan. Se dispara pasando datos malformados (nil) a cada parser.
  describe "rescues de parseo (no explotan)" do
    {
      parse_errors:       :error_parser,
      parse_events:       :events_parser,
      parse_observations: :observation_parser
    }.each do |method, key|
      it "##{method} con dato inválido registra un String en errors[#{key.inspect}] sin levantar" do
        expect { adapter.public_send(method, nil) }.not_to raise_error
        expect(adapter.errors[key]).to be_a(String)
      end
    end

    it "parse_fe_comp_consultar_response con response vacío no levanta NameError" do
      adapter.response = {}
      expect { adapter.parse_fe_comp_consultar_response }.not_to raise_error
      expect(adapter.errors[:fecomp_consult_response_parser]).to be_a(String)
    end
  end
end
