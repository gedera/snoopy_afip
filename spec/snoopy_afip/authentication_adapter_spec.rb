require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

RSpec.describe Snoopy::AuthenticationAdapter do
  describe "#build_tra" do
    it "construye el TRA (loginTicketRequest) para el servicio wsfe" do
      xml = described_class.new.build_tra
      expect(xml).to include("loginTicketRequest")
      expect(xml).to include("wsfe")
      expect(xml).to include("uniqueId")
    end
  end

  describe "credenciales de instancia" do
    it "expone pkey y cert recibidos" do
      auth = described_class.new(pkey: "/tmp/pkey", cert: "/tmp/cert")
      expect(auth.pkey).to eq("/tmp/pkey")
      expect(auth.cert).to eq("/tmp/cert")
    end
  end
end
