require "rmenu/dmenu_wrapper"

module RMenu
  class Main < DMenuWrapper

    attr_accessor :config_file
    attr_accessor :config
    attr_accessor :dmenu_thread_flag
    attr_accessor :dmenu_thread
    attr_accessor :current_menu

    include Utils

    def initialize(params = {})
      @config_file = params[:config_file]
      load_config
      @config.merge! params
      super @config
      @config[:locale] ||= "it"
      @waker_io = @config[:waker_io]
      self.items = build_items
    end

    def start
      self.dmenu_thread_flag = true
      self.dmenu_thread = Thread.new do
        while dmenu_thread_flag do
          $logger.info "#{self.class} is ready and listening on #{@waker_io}"
          wake_code = IO.read(@waker_io).chomp.strip
          $logger.debug "Received wake code <#{wake_code}>"
          set_params config.merge items: self.items
          self.current_menu = items
          item = get_item
          results = call item
          $logger.debug "PROCESS_CMD RESULTS: #{results.inspect}"
        end
      end
      begin
        if block_given?
          yield
        else
          self.dmenu_thread.join
        end
        stop
      rescue Interrupt
        $logger.info "Interrut catched...exiting."
        stop
      end
    end

    def stop
      @dmenu_thread_flag = false
      sleep(1) && @dmenu_thread && @dmenu_thread.kill
    end

    def load_config
      raise ArgumentError.new "File #{@config_file} does not exists" unless File.exists? @config_file
      @config = YAML.load_file @config_file
    end

    def save_config
      File.write @config_file, YAML.dump(@config)
    end

    def build_items(rebuild = false)
      self.items = []
      # Rebuild application items (XDG .desktop directory)
      self.items += apps_items if rebuild
      # Load saved items
      self.items += load_items.uniq
      # Rmenu commands into a submenu
      self.items += rmenu_items.uniq
      # Tails Rmenu commands to the root of items
      self.items += rmenu_items[0].value.uniq.flatten
      self.items.uniq!
      self.items
    end

    def load_items
      YAML.load_file config[:items_file] || []
    end

    def save_items
      items_to_save = items.select { |i| !i.options[:virtual] }
      File.write config[:items_file], YAML.dump(items_to_save)
    end

    def add_item(item)
      current_menu.insert 1, item
      current_menu.uniq!
      save_items
      item
    end

    def delete_item(item)
      current_menu.delete item
      current_menu.uniq!
      save_items
      item
    end

    def create_item
      dialog = DMenuWrapper.new config
      dialog.prompt = "Add Item"
      item = dialog.get_item
      item.value = ":add #{item.value}"
      call item
    end

    def destroy_item
      call Item.new(":delete", ":delete")
    end

    def notify(msg)
      notifier = DMenuWrapper.new config
      notifier.prompt = msg
      notifier.get_item
    end

    def pick_item(prompt, items)
      picker = DMenuWrapper.new config
      picker.prompt = prompt
      picker.items = items.map { |i| (i.is_a? Item) ? i : Item.new(i.to_s, i.to_s) }
      item = picker.get_item
    end

    def call(item)
      $logger.debug "Selected #{item.inspect}"

      if item.value.is_a? Symbol
        if self.respond_to? item.value
          self.send item.value
        else
          item.value = ":" + item.value.to_s
          proc_string_item item
        end

      elsif item.value.is_a? String
        return if item.value && item.value.nil? || item.value.empty?
        proc_string_item item

      elsif item.value.is_a? Array
        self.current_menu = item.value
        submenu = DMenuWrapper.new config
        submenu.prompt = item.key
        submenu.items = item.value
        item = submenu.get_item
        call item
      elsif item.value.is_a? Proc
        catch_and_notify_exception do
          item.value.call self
        end
      end

    end

    private

    def rmenu_items
      [ Item.format!(" **RMenu Commands**", [
        Item.format!("Config", :conf, virtual: true),
        Item.format!("Quit", :stop, virtual: true),
        Item.format!("Save config", :save_config, virtual: true),
        Item.format!("Reload config", :load_config, virtual: true),
        Item.format!("Save Items", :save_items, virtual: true),
        Item.format!("Load Items", :load_items, virtual: true)
      ], virtual: true)
      ]
    end

    def apps_items
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

    def replace_tokens(cmd)
      picker = DMenuWrapper.new config
      replaced_cmd = cmd.clone
      while md = replaced_cmd.match(/(__(.+?)__)/)
        break unless md[1] || md[2]
        picker.prompt = md[2]
        input = picker.get_item
        replaced_cmd.sub!(md[0], input.value)
      end
      $logger.debug "Command interpolated with input tokens: #{replaced_cmd}"
      replaced_cmd
    end

    def replace_blocks(cmd)
      replaced_cmd = cmd.clone
      catch_and_notify_exception do
        while md = replaced_cmd.match(/(\{([^\{\}]+?)\})/)
          break unless md[1] || md[2]
          replaced_cmd.sub!(md[0], self.instance_eval(md[2]).strip.to_s)
        end
        replaced_cmd
      end
      $logger.debug "Command interpolated with eval blocks: #{replaced_cmd}"
      replaced_cmd
    end

    def proc_string_item(item)
      if md = item.value.match(/^:conf\s*(.*)$/)
        if md[1] && !md[1].empty?
          val = config[md[1].to_sym]
          item = pick_item "Config[#{md[1]}]", [ Item.new(val,val)]
          config[md[1].to_sym] = item.value
          $logger.debug "CONF #{config.inspect}"
        else
          picker = DMenuWrapper.new config
          picker.prompt = "CONFIG"
          picker.items = config.map { |conf,val| Item.new(conf,":conf #{conf}") }
          item = picker.get_item
          call item
        end
      elsif md = item.value.match(/^:add\s+(.+)/)
        if md[1] && ( md = md[1].match(/(.+)\s*#\s*(.*)/) )
          value = md[1]
          key = md[2] || value
          item = Item.format!(key, value)
          add_item item
        end
      elsif md = item.value.match(/^:delete/)
        $logger.debug ":delete command called"
        item = pick_item "Delete item", current_menu
        $logger.debug "indexed item = #{item.inspect}"
        delete_item item
      elsif md = item.value.match(/^:(.+)/)
        catch_and_notify_exception do
          self.instance_eval md[1].strip.to_s
        end
      elsif md = item.value.match(/^!\s*(.+)/)
        exec_string md[1]
      else
        exec_string item.value
      end
    end

    def exec_string(cmd)
      replaced_cmd = replace_tokens cmd
      return if replaced_cmd && replaced_cmd.nil? || replaced_cmd.empty?
      replaced_cmd = replace_blocks replaced_cmd
      return if replaced_cmd && replaced_cmd.nil? || replaced_cmd.empty?
      if md = replaced_cmd.match(/^http(s?):\/\//)
        system_exec config[:web_browser], "\"", utils.str2url(replaced_cmd.strip), "\""
      elsif md = replaced_cmd.strip.match(/(.+);$/)
        system_exec config[:terminal], "\"", md[1], "\""
      else
        system_exec replaced_cmd
      end
    end

    def system_exec(*cmd)
      cmd << "&"
      cmd = cmd.join " "
      $logger.debug "RMenu.system_exec: #{cmd}"
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
