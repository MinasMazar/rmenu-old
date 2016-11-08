
module RMenu
  module Plugins
    class Context

      def load_plugin(plugin)
        begin
          load plugin.pathname
        rescue RuntimeError => e
          $logger.debug "Exception occurred while loading plugin #{plugin.pathname}"
          return e
        end
      end

    end
  end
end
