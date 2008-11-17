module Unison
  module Tuples
    class Tuple
      include Unison
      include Retainable      
      class << self
        def [](attribute)
          set[attribute]
        end

        def basename
          name.split("::").last
        end
      end

      def initialize
        @update_subscription_node = SubscriptionNode.new(self)
      end

      def bind(expression)
        case expression
        when Attributes::Attribute
          self[expression]
        else
          expression
        end
      end

      def on_update(*args, &block)
        update_subscription_node.subscribe(*args, &block)
      end

      protected
      attr_reader :update_subscription_node

      def attribute_for(attribute_or_name)
        case attribute_or_name
        when Attributes::Attribute
          attribute_or_name
        when Symbol
          set[attribute_or_name]
        else
          raise ArgumentError, "attribute_for only accepts an Attribute or Symbol"
        end
      end
    end    
  end
end