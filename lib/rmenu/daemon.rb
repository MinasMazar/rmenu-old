require "rmenu/profiles/base"

module RMenu
  class Daemon < Profiles::Main

    attr_accessor :config_file
    attr_accessor :waker_io
    attr_accessor :dmenu_thread_flag
    attr_accessor :dmenu_thread
    attr_accessor :current_profile
    attr_accessor :current_item

    def initialize(params = {})
      @config_file = params[:config_file]
      load_config
      config.merge! params
      super config
      @waker_io = @config[:waker_io]
      @current_profile = Profiles::DEFAULT
    end

    def start
      self.dmenu_thread_flag = true
      self.dmenu_thread = Thread.new do
        while dmenu_thread_flag do
          $logger.info "#{self.class} is ready and listening on #{@waker_io}"
          wake_code = IO.read(@waker_io).chomp.strip
          $logger.debug "Received wake code <#{wake_code}>"
          current_profile_instance = select_profile wake_code
          item = current_profile_instance.get_item
          results = proc item
          $logger.debug "Proc item returns #{results.inspect}"
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
      save_items
      @dmenu_thread_flag = false
      sleep(1) && @dmenu_thread && @dmenu_thread.kill
    end

    def load_config
      raise ArgumentError.new "File #{@config_file} does not exists" unless File.exists? @config_file
      self.config = YAML.load_file @config_file
    end

    def save_config
      File.write @config_file, YAML.dump(@config)
    end

    def notify(msg)
      notifier = DMenuWrapper.new config
      notifier.prompt = msg
      notifier.get_item
    end

    def pick(prompt, items = [])
      picker = DMenuWrapper.new config
      picker.prompt = prompt
      picker.items = items.map { |i| (i.is_a? Item) ? i : Item.new(i.to_s, i.to_s) }
      picker.get_item
    end

    def select_profile(code)
      code = code.to_sym
      self.current_profile = registered_profiles[code] || Profiles::DEFAULT
      registered_profiles[current_profile].new config
    end

  end
end
