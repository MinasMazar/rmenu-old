require "rmenu/utils"

module RMenu
  class DMenuWrapper

    def self.usage
      `dmenu --help 2>&1`.gsub(/(\n|\s)+/, " ")
    end

    attr_getter_and_setter :items
    attr_getter_and_setter :position
    attr_getter_and_setter :case_insensitive
    attr_getter_and_setter :lines
    attr_getter_and_setter :font
    attr_getter_and_setter :background
    attr_getter_and_setter :foreground
    attr_getter_and_setter :selected_background
    attr_getter_and_setter :selected_foreground
    attr_getter_and_setter :prompt

    attr_getter_and_setter :x, :y, :width

    def set_params(params = {})
      params = params.reject { |m| !respond_to? m }
      @items               = []
      @position            = :top
      @case_insensitive    = false
      @lines               = 1
      @font                = nil
      @background          = nil
      @foreground          = nil
      @selected_background = nil
      @selected_foreground = nil
      @prompt              = nil
      @other_params        = ""
      params.each do |a, v|
        self.send "#{a}=", v
      end
      if block_given?
        instance_eval &Proc.new
      end
    end

    def initialize(params = {})
      set_params params
    end

    def items=(items)
      raise ArgumentError.new "Items array expected, got #{items.inspect}" unless items.kind_of? Array
      @items = items
    end

    def get_item
      #run__sys_call_impl
      run__pipe_impl
    end

    def get_string
      get_item[:value]
    end

    def get_array
      get_string.split(" ")
    end

    private

    # Launches dmenu, displays the generated menu and waits for the user
    # to make a choice.
    #
    # @return [Item, nil] Returns the selected item or nil, if the user
    #   didn't make any selection (i.e. pressed ESC)
    def run__pipe_impl
      pipe = IO.popen(command, "w+")
      items.each do |item|
        pipe.puts item[:label]
      end

      pipe.close_write
      $logger.debug  "PipeCommand: #{command} "
      value = pipe.read
      pipe.close
      $logger.debug "#{$?.class} => #{$?.inspect}"
      if $?.exitstatus > 0
        selection = ""
      end
      value.chomp!
      selection = items.find do |item|
        item[:label].to_s == value
      end
      return selection || { key: value }
    end

    def run__sys_call_impl
      cmd = "echo -n \"#{items.map { |i| i[:label] }.join "\n"}\" | #{command.join " "} "
      value = `#{cmd}`
      $logger.debug  "Systemcall: #{cmd} => #{value}"
      selection = items.find do |item|
        item[:label].to_s == value
      end
      return selection || { key: value }
    end

    def command
      args = ["dmenu"]

      if @position == :bottom
        args << "-b"
      end

      if @case_insensitive
        args << "-i"
      end

      @lines = @lines.to_i
      if @lines > 1
        args << "-l"
        args << lines.to_s
      end

      h = {
        "-fn" => @font,
        "-nb" => @background,
        "-nf" => @foreground,
        "-sb" => @selected_background,
        "-sf" => @selected_foreground,
        "-p"  => @prompt,
        "-x" => x,
        "-y" => y,
        "-w" => width,
      }

      h.each do |flag, value|
        value = value.to_s
        if value && !value.empty?
          args << flag
          args << value
        end
      end

      args << @other_params unless @other_params.empty?

      return args
    end

  end
end
