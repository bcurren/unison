require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module Unison
  module Tuple
    describe Signal do
      attr_reader :user, :attribute, :signal
      before do
        @user = User.find(1)
        @attribute = users_set[:name]
        @signal = user.signal(attribute)
      end

      describe "#to_arel" do
        it "delegates to #value.to_arel" do
          signal.to_arel.should == user[:name].to_arel
        end
      end

      context "when #retained?" do
        before do
          signal.retained_by(Object.new)
        end

        it "retains its Tuple" do
          user.should be_retained_by(signal)
        end

        describe "#value" do
          it "returns the #attribute value from the #tuple" do
            user[:name].should_not be_nil
            signal.value.should == user[:name]
          end
        end

        describe "#after_last_release" do
          it "releases its Tuple" do
            signal.retained_by(Object.new)
            user.should be_retained_by(signal)
            signal.send(:after_last_release)
            user.should_not be_retained_by(signal)
          end

          context "when the Signal is registered in Tuple#signals[#attribute]" do
            it "removes itself from its Tuple#signals hash" do
              user.send(:signals)[users_set[:name]].should == signal
              signal.send(:after_last_release)
              user.send(:signals)[users_set[:name]].should be_nil
            end
          end

          context "when Signal is not registered in Tuple#signals[#attribute]" do
            it "removes itself from its Tuple#signals hash" do
              signal.send(:after_last_release)
              lambda do
                signal.send(:after_last_release)
              end.should raise_error
            end
          end
        end

        describe "#on_update" do
          context "when passed a block" do
            it "returns a Subscription" do
              signal.on_update {}.class.should == Subscription
            end

            context "when the #attribute's value is updated on the Tuple" do
              it "invokes the block" do
                on_update_arguments = []
                signal.on_update do |*args|
                  on_update_arguments.push(args)
                end

                old_name = user[:name]
                new_name = "Joe Bob"
                user[:name] = new_name
                on_update_arguments.should == [
                  [user, old_name, new_name]
                ]
              end
            end

            context "when another #attribute's value is updated on the Tuple" do
              it "does not invoke the block" do
                signal.on_update do |*args|
                  raise "Do not call me"
                end

                user[:id] = 100
              end
            end
          end
        end
      end

      context "wheretained_by#retained?" do
        describe "#after_first_retain" do
          it "retains and subscribes to its Tuple" do
            mock.proxy(signal).after_first_retain

            user.should_not be_retained_by(signal)
            signal.send(:tuple_subscription).should be_nil

            signal.retained_by(Object.new)
            user.should be_retained_by(signal)
            signal.send(:tuple_subscription).should_not be_nil
          end
        end
      end
    end
  end
end
