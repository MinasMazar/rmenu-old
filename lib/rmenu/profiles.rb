module RMenu
  module Profiles

    module Register

      @@registered_profiles = {}

      def self.included(klass)
        klass.extend self
        klass.register_profile
      end

      def registered_profiles
        @@registered_profiles
      end

      def register_profile(id = nil)
        id ||= self.to_s.split("::").last.downcase.to_sym
        @@registered_profiles[id] = self
      end

    end
  end
end

require "rmenu/dmenu_wrapper"
require "rmenu/profiles/base"
require "rmenu/profiles/main"
require "rmenu/profiles/introspectable"
