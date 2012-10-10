# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class XenServer6 < ProjectRazor::ModelTemplate::XenServer

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "xenserver_6"
        @description = "Citrix XenServer 6 Deployment"
        @osversion = "6"
        from_hash(hash) unless hash == nil
      end
    end
  end
end

