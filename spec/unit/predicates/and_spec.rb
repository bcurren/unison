require File.expand_path("#{File.dirname(__FILE__)}/../../unison_spec_helper")

module Unison
  module Predicates
    describe And do
      attr_reader :user, :predicate, :signal, :child_predicate_without_signal, :child_predicate_subscribed_signal

      before do
        @user = User.find("nathan")
        @signal = user.signal(:name)
        @child_predicate_without_signal = EqualTo.new(users_set[:id], "nathan")
        @child_predicate_subscribed_signal = EqualTo.new(signal, "Nathan")
        @predicate = And.new(child_predicate_without_signal, child_predicate_subscribed_signal)
      end

      describe "#eval" do
        context "when the passed in Tuple causes all of the child Predicates to #eval to true" do
          it "returns true" do
            user = User.find("nathan")
            user.id.should == "nathan"
            user.name.should == "Nathan"
            predicate.eval(user).should be_true
          end
        end

        context "when the passed in Tuple causes one of the child Predicates to not #eval to true" do
          it "returns false" do
            user = User.find("corey")
            user.name = "Nathan"
            predicate.eval(user).should be_false
          end
        end
      end

      describe "#fetch_arel" do
        it "return fetch_arel value of each operand joined by and" do
          predicate.fetch_arel.should == child_predicate_without_signal.fetch_arel.and(child_predicate_subscribed_signal.fetch_arel)
        end
      end
    end
  end
end
