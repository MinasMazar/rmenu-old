
module RMenu
  module Profiles

    class Main < Base

      register_profile

      attr_flag :item_added

      def initialize(params = {})
        super params
      end

      def add_item(item)
        items.insert 1, item
        items.uniq!
        save_items
        item_added!
        item
      end

      def delete_item(item)
        items.delete item
        items.uniq!
        save_items
        item
      end

      def prepare
        super
        items.sort_by! { |i| -1 * ( i.options[:picked] || 0 ) }
        reset_item_added
      end

      def build_items
        items = []
        # Load saved items
        items += load_items.uniq
        # Rmenu commands into a submenu
        items << rmenu_items
        # Uniq elements and put most picked ont top
        items.uniq
      end

      def load_items
        return nil unless File.exist? config[:items_file]
        utils.load_items config[:items_file]
      end

      def save_items
        return nil unless File.exist? config[:items_file]
        items_to_save = items.reject { |i| i.options[:virtual] }
        utils.save_items items_to_save, config[:items_file]
      end

      def conf field = nil
        if field
          field = field.to_sym
          val = config[field]
          item = pick "Config[#{field}]: #{val}"
          unless item.blank?
            $logger.debug "Config modified: config[:#{field}] #{val} -> #{item.value}"
            config[field] = item.value
          end
        else
          picker = DMenuWrapper.new config
          picker.prompt = "Config"
          picker.items = config.map { |conf,v| Item.new(conf, conf) }
          picker.lines = config.size
          item = picker.get_item
          conf item.value unless item.blank?
        end
      end

      def add item_str = nil
        item = Item.parse item_str
        add_item item if item
      end

      def delete
        $logger.debug ":delete command called"
        item = pick "Delete item", items
        $logger.debug "indexed item = #{item.inspect}"
        delete_item item
      end

      def rmenu_items
        edit_build_launch_proc = Proc.new do |to_edit|
          proc_string ":conf text_editor"
          build_items
        end
        submenu = []
        submenu << Item.format!("Edit config on the fly", :conf, virtual: true)
        if config[:text_editor]
          submenu << Item.format!("Edit configuration file", "#{config[:text_editor]} #{config[:config_file]}", virtual: true)
        else
          submenu << Item.format!("Edit configuration file (disabled: define config[:text_editor])", edit_build_launch_proc, virtual: true)
        end
        submenu << Item.format!("Load config", :load_config, virtual: true)
        submenu << Item.format!("Save config", :save_config, virtual: true)
        if config[:text_editor]
          submenu << Item.format!("Edit items file", "#{config[:text_editor]} #{config[:items_file]}", virtual: true)
        else
          submenu << Item.format!("Edit items file (disabled: define config[:text_editor])", edit_build_launch_proc, virtual: true)
        end
        submenu << Item.format!("Load items", :load_items, virtual: true)
        submenu << Item.format!("Save items", :save_items, virtual: true)
        submenu << Item.format!("Quit RMenu", :stop, virtual: true)
        Item.format!("RMenu", submenu, virtual: true)
      end

      def proc(item)
        super item
        if item && !item.options[:virtual]
          item.options[:picked] ||= 0
          item.options[:picked] += 1
        end
      end

      def proc_string(str)
        super str
        cmd, label = nil
        if md = str.match(/(.+)\s*#\s*(.+)/)
          cmd, label = md[1], md[2].strip
          item = Item.format!(label, cmd, user_defined: true)
          add_item item unless item_added?
        end
      end

    end
  end
end
