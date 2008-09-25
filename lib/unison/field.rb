module Unison
  class Field
    attr_reader :tuple, :attribute, :value

    def initialize(tuple, attribute)
      @tuple, @attribute = tuple, attribute
      @dirty = false
    end

    def set_default_value
      if attribute.is_a?(Attributes::PrimitiveAttribute)
        if attribute.default.is_a?(Proc)
          set_value(tuple.instance_eval(&attribute.default))
        else
          set_value(attribute.default) unless attribute.default.nil?
        end
      end
    end
    
    def set_value(new_value)
      old_value = value
      converted_new_value = attribute.convert(new_value)
      if old_value != converted_new_value
        @value = converted_new_value
        yield(attribute, old_value, converted_new_value) if block_given?
        @dirty = true
      end
      converted_new_value
    end

    def dirty?
      @dirty ? true : false
    end

    def pushed
      @dirty = false
    end

    def ==(other)
      other.is_a?(Field) && other.attribute == attribute && other.value == value
    end
  end
end