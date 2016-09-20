module RMenu

  class ::Object
    def object_methods
      self.methods - self.class.ancestors.first.methods
    end
  end

  module GettersAndSetters

    def attr_getter(*args)
      args.each do |arg|
        attr_reader arg
        define_method "get_#{arg}" do
          instance_variable_get "@#{arg}"
        end
      end
    end

    def attr_setter(*args)
      args.each do |arg|
        attr_writer arg
        define_method "set_#{arg}" do |par|
          instance_variable_set "@#{arg}", par
        end
      end
    end

    def attr_getter_and_setter(*args)
      args.each do |arg|
        attr_getter arg
        attr_setter arg
      end
    end

  end
end
