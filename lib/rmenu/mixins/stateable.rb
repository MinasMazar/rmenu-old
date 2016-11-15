
module RMenu
  module Mixins
    module Stateable

      module ClassMethods

        def add_state(state)
          state = state.to_sym
          define_method "is_#{state}_state?" do
            states[state]
          end
          define_method "activate_#{state}_state" do
            states[state] = true
          end
          define_method "deactivate_#{state}_state" do
            states[state] = false
          end
          define_method "toggle_#{state}_state" do
            states[state] = !states[state]
          end
        end

      end

      def states
        @states ||= {}
      end

      def self.included(klass)
        klass.extend ClassMethods
      end

    end
  end
end
