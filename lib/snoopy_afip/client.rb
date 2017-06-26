module Snoopy
  class Client
    attr_accessor :savon

    def initialize(attrs)
      @savon = Savon.client(attrs)
    end

    def call service, args={}
      Timeout::timeout(5) do
        savon.call(service, args).body
      end
    rescue Timeout::Error
      raise Snoopy::Exception::ServerTimeout.new
    rescue => e
      raise Snoopy::Exception::ClientError.new(e.message)
    end

  end
end
