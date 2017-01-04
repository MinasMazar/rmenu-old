require "rmenu/dmenu_wrapper"

module RMenu
  module Profiles
    class Base < DMenuWrapper

      include Profiles::Register
      include Utils

      attr_accessor :config


      def initialize(params = {})
        @config = params
        super @config
        @config[:locale] ||= "it"
        build_items
      end

      def build_items(rebuild = false)
        self.items = []
      end

      def prepare
        set_params config.merge items: items
      end

      def get_item
        prepare
        super
      end

      def proc(item)
        $logger.debug "Selected #{item.inspect}"

        if item[:key].is_a? Symbol
          self.send item[:key] if self.respond_to? item[:key]

        elsif item[:key].is_a? String
          return if item[:key].nil? || item[:key].empty?
          proc_string item[:key]

        elsif item[:key].is_a? Array
          submenu = DMenuWrapper.new config
          submenu.prompt = item[:label]
          submenu.items = item[:key]
          item = submenu.get_item
          proc item

        elsif item[:key].is_a? Proc
          catch_and_notify_exception do
            item[:key].call self
          end
        end
      end

      def proc_string(str)
        if md = str.match(/^\s*(\{\{(.+)\}\})/)
          string_to_eval = self.instance_eval(md[2]).to_s
          instance_eval string_to_eval
        elsif md = str.match(/^:\s*(.+)/)
          catch_and_notify_exception do
            meth = md[1].split[0]
            args = md[1].split[1..-1]
            if args.any?
              send meth, *args.join(" ")
            else
              send meth
            end
          end
        elsif md = str.match(/^!\s*(.+)/)
          exec_command md[1]
        elsif !str.empty?
          exec_command str
        end
      end

      def exec_command(cmd)
        replaced_cmd = replace_tokens cmd
        return unless replaced_cmd
        replaced_cmd = replace_blocks replaced_cmd
        return unless replaced_cmd
        if md = replaced_cmd.match(/^http(s?):\/\//)
          unless config[:web_browser]
            conf :web_browser
          else
            system_exec config[:web_browser], "\"", utils.str2url(replaced_cmd.strip), "\""
          end
        elsif md = replaced_cmd.strip.match(/(.+);$/)
          if config[:terminal]
            conf :terminal
          else
            system_exec config[:terminal], md[1].strip
          end
        else
          system_exec replaced_cmd
        end
      end

      def replace_tokens(cmd)
        replaced_cmd = cmd.clone
        while md = replaced_cmd.match(/(__(.+?)__)/)
          break unless md[1] || md[2]
          input = pick md[2]
          return if input[:key] == "quit"
          replaced_cmd.sub!(md[0], input[:key])
        end
        $logger.debug "Command interpolated with input tokens: #{replaced_cmd}"
        replaced_cmd
      end

      def replace_blocks(cmd)
        replaced_cmd = cmd.clone
        catch_and_notify_exception do
          while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
            break unless md[1] || md[2]
            evaluated_string = self.instance_eval(md[2]).to_s
            return if evaluated_string == :quit
            replaced_cmd.sub!(md[0], evaluated_string)
          end
          replaced_cmd
        end
        $logger.debug "Command interpolated with eval blocks: #{replaced_cmd}"
        replaced_cmd
      end

      def notify(msg)
        notifier = DMenuWrapper.new config
        notifier.prompt = msg
        notifier.get_item
      end

      def pick(prompt, items = [])
        picker = DMenuWrapper.new config
        picker.prompt = prompt
        picker.items = items
        picker.get_item
      end

      def system_exec(*cmd)
        cmd << "&"
        cmd = cmd.join " "
        $logger.debug "RMenu.system_exec: [#{cmd}]"
        catch_and_notify_exception do
          system cmd
        end
      end

      def system_exec_and_get_output(*cmd)
        cmd = cmd.join " "
        $logger.debug "RMenu.system_exec: #{cmd}"
        catch_and_notify_exception "RMenu.system_exec error: #{e.inspect}" do
          `#{cmd} &`
        end
      end

      def current_directory
        File.expand_path "~"
      end

      def catch_and_notify_exception(msg = "")
        begin
          yield
        rescue StandardError => e
          $logger.debug "Exception catched[#{msg}] #{e.inspect} at #{e.backtrace.join("\n")}"
          notify "Exception catched[#{msg}] #{e.inspect}"
        end
      end

    end
  end
end
