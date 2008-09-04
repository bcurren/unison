module Unison
  module Relations
    class Relation
      instance_methods.each do |m|
        unless m =~ /(^__|^methods$|^respond_to\?$|^instance_of\?$|^equal\?$|^is_a\?$|^extend$|^class$|^nil\?$|^send$|^object_id$|^should|^instance_eval$)/
          undef_method m
        end
      end

      include Retainable
      def initialize
        @insert_subscription_node = SubscriptionNode.new
        @delete_subscription_node = SubscriptionNode.new
        @tuple_update_subscription_node = SubscriptionNode.new
        @singleton = false
        @tuples = nil
      end

      def to_sql
        to_arel.to_sql
      end

      def [](index)
        case index
        when Symbol
          attribute(index)
        when Integer
          delegate_to_read(:[], index)
        else
          raise ArgumentError, "[] does not support #{index.inspect} as an argument"
        end
      end

      def pull(repository)
        merge(repository.fetch(self))
      end

      def push(repository)
        if compound?
          composed_sets.each do |component_set|
            repository.push(self.project(component_set))
          end
        else
          repository.push(self)
        end
      end

      def find(id)
        where(self[:id].eq(id)).first
      end

      def where(predicate)
        Selection.new(self, predicate)
      end

      def join(operand_2)
        PartialInnerJoin.new(self, operand_2)
      end

      def project(attributes)
        Projection.new(self, attributes)
      end

      def order_by(attribute)
        Ordering.new(self, attribute)
      end

      def tuples
        retained?? @tuples : initial_read
      end

      def compound?
        composed_sets.size > 1
      end

      def tuple
        raise "Relation must be singleton to call #tuple" unless singleton?
        tuples.first
      end

      def nil?
        singleton?? tuples.first.nil? : false
      end

      def singleton
        @singleton = true
        self
      end

      def singleton?
        @singleton
      end

      def on_insert(&block)
        raise "Relation must be retained" unless retained?
        insert_subscription_node.subscribe(&block)
      end

      def on_delete(&block)
        raise "Relation must be retained" unless retained?
        delete_subscription_node.subscribe(&block)
      end

      def on_tuple_update(&block)
        raise "Relation must be retained" unless retained?
        tuple_update_subscription_node.subscribe(&block)
      end

      def inspect
        "<#{self.class}:#{object_id}>"
      end

      def ==(other)
        if other.is_a?(Relation)
          tuples == other.tuples
        else
          method_missing(:==, other)
        end
      end

      alias_method :to_ary, :tuples

      protected
      attr_reader :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node

      def insert(tuple)
        raise "Relation must be retained" unless retained?
        tuple.retained_by(self)
        add_to_tuples(tuple)
        insert_subscription_node.call(tuple)
        tuple
      end

      def add_to_tuples(tuple)
        tuples.push(tuple)
      end

      def delete(tuple)
        tuple.released_by(self)
        tuples.delete(tuple)
        delete_subscription_node.call(tuple)
        tuple
      end

      def after_first_retain
        @tuples = []
        initial_read.each do |tuple|
          insert(tuple)
        end
      end

      def initial_read
        raise NotImplementedError
      end

      def method_missing(method_name, *args, &block)
        delegate_to_read(method_name, *args, &block)
      end

      def delegate_to_read(method_name, *args, &block)
        if singleton?
          tuples.first.send(method_name, *args, &block)
        else
          tuples.send(method_name, *args, &block)
        end
      end
    end
  end
end