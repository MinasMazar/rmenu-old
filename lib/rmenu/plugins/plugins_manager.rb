module RMenu
  module Plugins
    class PluginManager

      attr_accessor :base_dir
      attr_accessor :plugins
      attr_accessor :context

      def initialize(base_dir)
        @base_dir = File.expand_path base_dir
        @context = Context.new
        @plugins = []
      end

      def list
        Dir[File.join(base_dir, "**/*.rb")]
      end

      def load_all
        list.map do |plugin_pathname|
          plugin = Plugin.new(plugin_pathname, context)
          unless plugins.include? plugin
            load_result = plugin.load
            plugins << plugin unless load_result.instance_of? StandardError
          end
        end
      end

    end
  end
end
