
module RMenu
  module Profiles

    class Main < Base

      register_profile

      attr_flag :item_added

      def initialize(params = {})
        super params
      end

      def prepare
        super
        items.sort_by! { |i| -1 * ( i[:picked] || 0 ) }
        reset_item_added
      end

      def add_item item
        super
        save_items
      end

      def build_items(rebuild = false)
        super
        # Rebuild application items (XDG .desktop directory)
        self.items += utils.build_desktop_application_menu.uniq if rebuild
        # Load saved items
        self.items += load_items
        # Rmenu commands into a submenu
        self.items += rmenu_items
        # Uniq elements and put most picked ont top
        self.items
        $logger.debug "Rebuilded items"
      end

      def load_items
        utils.load_items config[:items_file]
      end

      def save_items
        items_to_save = items.reject { |i| i[:virtual] }
        utils.save_items items_to_save, config[:items_file]
        $logger.info "Saved items on #{config[:items_file]}"
      end

      def conf field = nil
        if field
          field = field[:label].to_sym
          val = config[field]
          item = pick "Config[#{field}]: #{val} [THIS CODE WILL BE EVALUATED]"
          item_evaluated = eval item[:key]
          $logger.debug "Config modified: config[:#{field}] #{val} -> #{item_evaluated}"
          config[field] = item_evaluated
        else
          picker = DMenuWrapper.new config
          picker.prompt = "Config"
          picker.items = config.map { |conf,v| { label: conf, key: v } }
          picker.lines = config.size
          item = picker.get_item
          conf item unless item.empty?
        end
      end

      def add item_str = nil
        item = { label: item_str, key: item_str }
        if md = item_str.match(/(.+?)\s*#\s*(.+)/)
          item = { label: md[2].strip, key: md[1].strip }
        end
        add_item item
        $logger.info "Added item #{item.inspect}"
      end

      def delete
        item = pick "Delete item", items
        delete_item item
        $logger.info "Deleted item #{item.inspect}"
      end

      def rmenu_items
        edit_build_launch_proc = Proc.new do |to_edit|
          proc_string ":conf text_editor"
          build_items
        end
        get_dmenu_usage_proc = Proc.new do
          notify DMenuWrapper.usage
        end
        menu, submenu = [], []
        submenu << { label: "Edit config on the fly", key: :conf, virtual: true }
        if config[:text_editor]
          submenu << { label: "Edit configuration file", key: "#{config[:text_editor]} #{config[:config_file]}", virtual: true }
        else
          submenu << { label: "Edit configuration file (disabled: define config[:text_editor])", key: edit_build_launch_proc, virtual: true }
        end
        submenu << { label: "Load config", key: :load_config, virtual: true }
        submenu << { label: "Save config", key: :save_config, virtual: true }
        if config[:text_editor]
          submenu << { label: "Edit items file", key: "#{config[:text_editor]} #{config[:items_file]}", virtual: true }
        else
          submenu << { label: "Edit items file (disabled: define config[:text_editor])", key: edit_build_launch_proc, virtual: true }
        end
        submenu << { label: "Load items", key: :build_items, virtual: true }
        submenu << { label: "Save items", key: :save_items, virtual: true }
        submenu << { label: "Quit RMenu", key: :stop, virtual: true }
        submenu << { label: "DMenu Executable", key: [
          { label: "Usage", key: get_dmenu_usage_proc, virtual: true }
        ], virtual: true}
        menu << { label: "RMenu", key: submenu, virtual: true }
        menu
      end

      def proc(item)
        super item
        if item && !item[:virtual]
          item[:picked] ||= 0
          item[:picked] += 1
        end
      end

      def proc_string(str)
        super str
        cmd, label = nil
        if md = str.match(/(.+)\s*#\s*(.+)/)
          cmd, label = md[1], md[2].strip
          item = { label: label, key: cmd, user_defined: true }
          add_item item unless item_added?
        end
      end

    end
  end
end
