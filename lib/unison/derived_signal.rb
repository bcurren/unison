module Unison
  class DerivedSignal < Signal
    include Retainable

    retain :source_signal
    subscribe do
      source_signal.on_update do |source_old_value, source_new_value|
        old_value = @value || transform.call(source_old_value)
        @value = transform.call(source_new_value)
        update_subscription_node.call(old_value, value)
      end
    end

    attr_reader :source_signal, :transform
    def initialize(source_signal, &transform)
      super()
      @source_signal, @transform = source_signal, transform
    end

    def value
      @value ||= transform.call(source_signal.value)
    end
  end
end
