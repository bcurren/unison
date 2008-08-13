module Unison
  class Repository
    attr_reader :connection
    def initialize(connection)
      @connection = connection
    end

    def fetch(relation)
      raise NotImplementedError if relation.is_a?(Relations::InnerJoin)
      connection[relation.to_sql].map do |record|
        relation.tuple_class.new(record)
      end
    end

    def push(relation)
      raise NotImplementedError if relation.is_a?(Relations::InnerJoin)
      relation.each do |tuple|
        tuple.persisted
      end
    end
  end
end