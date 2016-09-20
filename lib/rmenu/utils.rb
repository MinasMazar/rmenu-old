module RMenu
  module Utils

    attr_accessor :utils_inst

    def utils
      self.utils_inst ||= Object.new.extend Utils
    end

    def str2url(str)
      str.gsub /\s+/, "+"
    end

  end
end
