require "rmenu/dmenu_wrapper"

module RMenu
  class Main < DMenuWrapper

    attr_accessor :config_file
    attr_accessor :config
    attr_accessor :dmenu_thread_flag
    attr_accessor :dmenu_thread

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
          item = get_item
          results = call item
          $logger.debug "PROCESS_CMD RESULTS: #{results.inspect}"
        end
      end
      begin
        self.dmenu_thread.join
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

    def build_items
      self.items = ( rmenu_items + load_items ).uniq
    end

    def load_items
      YAML.load_file config[:items_file] || []
    end

    def save_items
      items_to_save = items.select { |i| !i.options[:virtual] }
      File.write config[:items_file], YAML.dump(items_to_save)
    end

    def add_item
      dialog = DMenuWrapper.new config
      dialog.prompt = "Add Item"
      dialog.items = [ Item.format!(":add ", ":add ")]
      item = dialog.get_item
      call item
    end

    def delete_item
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
        submenu = DMenuWrapper.new config
        submenu.prompt = item.key
        submenu.items = item.value
        item = submenu.get_item
        call item

      elsif item.value.is_a? Proc
        begin
          item.value.call self
        rescue StandardError => e
          notify "Exception catched: #{e.inspect}"
          $logger.debug "Exception catched: #{e.inspect}"
        end
      end

    end

    private

    def rmenu_items
      [ Item.format!(" **RMenu Commands**", [
        Item.format!("Add Item", :add_item),
        Item.format!("Delete Item", :delete_item),
        Item.format!("Config", :conf),
        Item.format!("Quit", :stop),
        Item.format!("Reload Config", :load_config),
        Item.format!("Save Items", :save_items),
        Item.format!("Load Items", :load_items)
      ], virtual: true)
      ]
    end

    def apps_items
        $logger.debug "Building items from /usr/share/applications desktop files"
        items = Dir["/usr/share/applications/*.desktop"].map do |e|
          $logger.debug "Parsing #{e}.."
          File.readlines(e).select { |l| l =~ /^(Exec|Name|Generic Name|Categories)(\[\w+\])?=/ if l.valid_encoding? }.map do |l|
            if md = l.match(/(.+?)=(.+)/)
              if md[1].match /(.+?)\[(\w+)\]/
                { "#{$1.downcase}_#{$2}".to_sym => md[2] }
              else
                { md[1].downcase.to_sym => md[2] }
              end
            end
          end.compact.reduce { |h,i| h.merge i }
        end
        items.uniq! { |i| i[:name] }.map! do |h|
          locale_name = h[ "name_#{config[:locale]}".to_sym ] || h[:name]
          categories = h[:categories] && h[:categories].split(";") || []
          Item.format! config[:locale], h[:exec], categories: categories
        end
        category_items = items.map do |i|
          i.options[:categories]
        end.flatten.compact.map do |cat|
          $logger.debug "Parsing category #{cat}"
          Item.format! cat, [ cat ] + items.find_all { |i| i.options[:categories].include? cat }
        end
        category_items + items
    end

    def replace_tokens(cmd)
      picker = DMenuWrapper.new config
      cmd_replaced = cmd
      while md = cmd.match(/(__(.+)__)/)
        break unless md[1] || md[2]
        picker.prompt = md[2]
        input = picker.get_item
        cmd_replaced.sub!(md[0], input.value)
      end
      $logger.debug "Command interpolated with input tokens: #{cmd_replaced}"
      cmd_replaced
    end

    def replace_blocks(cmd)
      cmd_replaced = cmd
      begin
        while md = cmd.match(/(\{([^\{\}]+?)\})/)
          break unless md[1] || md[2]
          cmd_replaced.sub!(md[0], self.instance_eval(md[2]).to_s)
        end
        cmd_replaced
      rescue StandardError => e
        $logger.debug "Exception catched while replacing blocks in the command: #{e.inspect}"
        notify "Exception catched while replacing blocks in the command: #{e.inspect}"
        cmd = nil
      end
      $logger.debug "Command interpolated with eval blocks: #{cmd_replaced}"
      cmd_replaced
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
          items.insert 1, item
          items.uniq!
          save_items
          item
        end
      elsif md = item.value.match(/^:delete/)
        $logger.debug ":delete command called"
        item = pick_item "Delete item", items
        $logger.debug "indexed item = #{item.inspect}"
        items.delete item
        items.uniq!
        save_items
        item
      else
        cmd = item.value
        cmd = replace_tokens cmd
        return if cmd && cmd.nil? || cmd.empty?
        cmd = replace_blocks cmd
        return if cmd && cmd.nil? || cmd.empty?
        if md = cmd.match(/^http(s?):\/\//)
          system_exec config[:web_browser], cmd
        elsif md = cmd.match(/(.+);$/)
          system_exec config[:terminal], "-e", "\"", cmd, "\""
        else
          system_exec cmd
        end
      end
    end

    def system_exec(*cmd)
      cmd << "&"
      cmd = cmd.join " "
      $logger.debug "RMenu.system_exec: #{cmd}"
      begin
        system cmd
      rescue Exception => e
        $logger.debug "RMenu.system_exec error: #{e.inspect}"
        @notifier.notify e.inspect if @notifier.respond_to? :notify
      end
    end

    def system_exec_and_get_output(*cmd)
      cmd = cmd.join " "
      $logger.debug "RMenu.system_exec: #{cmd}"
      begin
        `#{cmd} &`
      rescue Exception => e
        $logger.debug "RMenu.system_exec error: #{e.inspect}"
        @notifier.notify e.inspect if @notifier.respond_to? :notify
      end
    end

    def current_directory
      File.expand_path "~"
    end

  end
end
