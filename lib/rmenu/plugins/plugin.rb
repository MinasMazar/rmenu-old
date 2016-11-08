module RMenu
  module Plugins
    class Plugin

      attr_accessor :pathname
      attr_accessor :context
      attr_flag :loaded

      def initialize(pathname, context)
        @pathname = pathname
        @context = context
        reset_loaded
      end

      def load
        return nil if loaded?
        context.load_plugin self
        loaded!
      end

      def ==(o)
        pathname == o.pathname
      end
      alias eql? ==

    end
  end
end
