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

      def build_desktop_application_menu
        $logger.debug "Building items from /usr/share/applications desktop files"
        items = Dir["/usr/share/applications/*.desktop"].map do |e|
          $logger.debug "Parsing #{e}.."
          item = {}
          File.readlines(e).each do |l|
            if md = l.match(/(Exec|Name)\s*=\s*(.+)/i)
              item[md[1].downcase.to_sym] = md[2].to_s
            end
          end
          unless item[:exec] && item[:exec].empty? && item[:name] && item[:name].empty?
            Item.format! "#{item[:name]} (#{item[:exec]})", item[:exec]
          end
        end
        items.compact.uniq
      end

    end

    @@utils_inst ||= Object.new.extend Methods

    def utils
      @@utils_inst
    end

  end
end
