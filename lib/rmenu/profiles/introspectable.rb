require "rmenu/dmenu_wrapper.rb"

module RMenu
  module Profiles
    class Introspectable < Main

      include RMenu::Mixins::Markable

      def add item_str = nil
        item = Item.parse item_str
        add_item item if item
      end

      def add_submenu name
        item = Item.format! name, []
        add_item item
      end

      def delete
        if marked_items.any?
          delete_item marked_items
        else
          item = pick "Delete item", items
          delete_item item
        end
      end

      def yank
        raise "NotImplementedYed"
      end

      def mark
        activate_mark_state
        self.selected_background = config[:marking_background]
        self.selected_foreground = config[:marking_foreground]
      end

      def unmark
        deactivate_mark_state
        self.selected_background = config[:selected_background]
        self.selected_foreground = config[:selected_foreground]
      end

      def marked_items
        items.select { |i| i.options[:mark] }
      end

      def proc(item)
        if is_mark_state?
          if items.include? item
            item.options[:mark] = !item.options[:mark]
          end
        end
        super item
        if item && !item.options[:virtual] && !is_mark_state?
          item.options[:picked] ||= 0
          item.options[:picked] += 1
        end
      end

      def proc_string(cmd)
        if is_mark_state?
          if md = cmd.match(/^:\s*(.+)/)
            catch_and_notify_exception do
              meth = md[1].split[0]
              args = md[1].split[1..-1]
              if args.any?
                send meth, *args.join(" ")
              else
                send meth
              end
            end
          end
        else
          super cmd
        end
        # Auto-add item if given with a label (i.e. command #label )
        _cmd, label = nil
        if md = cmd.match(/(.+)\s*#\s*(.+)/)
          _cmd, label = md[1], md[2].strip
          item = Item.format!(label, _cmd, user_defined: true)
          add_item item unless item_added?
        end
      end

    end
  end
end
