module RMenu
  module Utils

    def utils
      self.utils_inst = Object.new.extend Utils
    end

    def str2url(str)
      url.gsub /\s+/, "+"
    end

  end
end
