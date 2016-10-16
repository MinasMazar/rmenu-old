module RMenu
  module Utils

    module Methods

      def load_items(items_file)
        YAML.load_file(items_file) || []
      end

      def save_items(items, items_file)
        File.write items_file, YAML.dump(items)
      end

      def str2url(str)
        str.gsub /\s+/, "+"
      end

    end

    @@utils_inst ||= Object.new.extend Methods

    def utils
      @@utils_inst
    end

  end
end
