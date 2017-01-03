module RMenu
  class Item
    def self.parse(str)
      key = nil
      options = {}
      value = nil
      if md = str.match(/\s*(.+?)(;?)\s*#(.+)/)
        key = md[3].strip
        options[:term_exec] = true if $2
        value = md[1]
        format! key, value, options
      else
        format! str, str, options
      end
    end

    def self.format!(key, value, options = {})
      if value.is_a? String
        new "#{key}", value, options
      elsif value.is_a? Symbol
        new "#{key}", value, options
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
end
