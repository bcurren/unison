require File.expand_path("#{File.dirname(__FILE__)}/../../unison_spec_helper")

module Unison
  module Predicates
    describe Gt do
      attr_reader :predicate, :operand_1, :operand_2

      before do
        @operand_1 = users_set[:id]
        @operand_2 = 2
        @predicate = Gt.new(operand_1, operand_2)
      end      
      
      describe "#to_arel" do
        it "returns an Arel::Where representation" do
          predicate.to_arel.should == Arel::GreaterThan.new(operand_1.to_arel, operand_2.to_arel)
        end
      end

      describe "#eval" do
        it "returns true if one of the operands is an attribute and its value in the tuple is > than the other operand" do
          predicate.eval(User.new(:id => operand_2 + 1)).should be_true
        end

        it "returns false if one of the operands is an attribute and its value in the tuple is not > than the other operand" do
          predicate.eval(User.new(:id => operand_2)).should be_false
        end

        context "when one of the operands is a Signal" do
          it "uses the value of the Signal in the predication" do
            user = User.new(:id => 1)
            Gt.new(1, user.signal(:id)).eval(user).should be_false
            Gt.new(user.signal(:id), 0).eval(user).should be_true
          end
        end
      end
    end
  end
end