module Snoopy
  class Authorizer
    attr_reader :pkey, :cert

    def initialize
      @pkey = Snoopy.pkey
      @cert = Snoopy.cert
    end
  end
end