# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class Windows2008R2 < ProjectRazor::ModelTemplate::Windows

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "windows_2008r2_7600"
        @description = "Microsoft Windows Server 2008 R2 Deployment"
        @osversion = "7600"
        from_hash(hash) unless hash == nil
      end
    end
  end
end

