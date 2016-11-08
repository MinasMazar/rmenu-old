module RMenu
  module Profiles

    DEFAULT = :main

    module Register

      @@registered_profiles = {}

      def self.included(klass)
        klass.extend self
      end

      def registered_profiles
        @@registered_profiles
      end

      def register_profile(id = nil)
        if self.respond_to?(:ancestors) && self.ancestors.include?(Profiles::Base)
          id ||= self.to_s.split("::").last.downcase.to_sym
          @@registered_profiles[id] = self
        else
          id ||= self.class.to_s.split("::").downcase.to_sym
          @@registered_profiles[id] = self.class
        end
      end

    end
  end
end

require "rmenu/dmenu_wrapper"
require "rmenu/profiles/base"
require "rmenu/profiles/main"
