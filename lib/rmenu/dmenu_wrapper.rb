require "rmenu/utils"

module RMenu
  class DMenuWrapper

    class Item
      def self.parse(str)
        key = nil
        options = {}
        value = nil
        if str =~ /(.+?)(;?)\s*#(.+)/
          key = $3
          options[:term_exec] = true if $2
          value = $1
        end
        if key && value
          new key, value, options
        end
      end

      def self.format!(key, value, options = {})
        if value.is_a? String
          new "%#{key}", value, options
        elsif value.is_a? Symbol
          new ":#{key}", value, options
        elsif value.is_a? Proc
          new "&#{key}", value, options
        elsif value.is_a? Array
          new ">#{key}", value, options
        elsif value.is_a? Item
          value
        else
          new key, value, options
        end
      end

      def self.separator
        Item.new "", nil
      end

      # @return [#to_s] The key is what will be displayed in the menu.
      attr_accessor :key
      # @return [Object] The value can be any kind of object you wish to
      #   assign to the key.
      attr_accessor :value
      #
      attr_reader :options
      def initialize(key, value, options = {})
        @key   = key
        @value = value
        @options = options
      end
      def inspect
        "<#{self.class}: (#{key} => #{value}), #{options.inspect}>"
      end
      def to_s
        key.to_s
      end
      def hash
        value.hash
      end
      def eql?(o)
        return false unless o.kind_of? Item
        value == o.value
      end
    end

    extend RMenu::GettersAndSetters

    # @return [Array<#to_s, Item>] Items to display in the menu. Items
    #   that are not an instance of the {Item} class will transparently
    #   be converted into one.
    attr_getter_and_setter :items
    # @return [Symbol<:top, :bottom>] Where to display the menu on screen.
    attr_getter_and_setter :position
    # @return [Boolean] If true, menu entries will be matched case insensitively.
    attr_getter_and_setter :case_insensitive
    # @return [Number] Number of lines to display. If >1, dmenu will go into vertical mode.
    attr_getter_and_setter :lines
    # @return [String] Which font to use.
    attr_getter_and_setter :font
    # @return [String] The background color of normal items.
    attr_getter_and_setter :background
    # @return [String] The foreground color of normal items.
    attr_getter_and_setter :foreground
    # @return [String] The background color of selected items.
    attr_getter_and_setter :selected_background
    # @return [String] The foreground color of selected items.
    attr_getter_and_setter :selected_foreground
    # @return [String] Defines a prompt to be displayed before the input area.
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

    def items
      @items.map! do |item|
        if item.is_a?(Item)
          item
        else
          Item.new(item, item)
        end
      end
    end

    def get_item
      #run__sys_call_impl
      run__pipe_impl
    end

    def get_string
      get_item.value
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
        pipe.puts item.to_s
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
        item.key.to_s == value
      end
      return selection || Item.new(value, value)
    end

    def run__sys_call_impl
      i = items.map {|i| "#{i.to_s}" }
      cmd = "echo -n \"#{i.join "\n"}\" | #{command.join " "} "
      value = `#{cmd}`
      $logger.debug  "Systemcall: #{cmd} => #{value}"
      selection = items.find do |item|
        item.key.to_s == value
      end
      return selection || Item.new(value, value)
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
        if value
          args << flag
          args << value
        end
      end

      args << @other_params unless @other_params.empty?

      return args
    end

  end
end
