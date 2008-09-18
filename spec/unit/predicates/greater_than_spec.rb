require File.expand_path("#{File.dirname(__FILE__)}/../../unison_spec_helper")

module Unison
  module Predicates
    describe GreaterThan do
      attr_reader :predicate, :operand_1, :operand_2

      before do
        @operand_1 = accounts_set[:employee_id]
        @operand_2 = 2
        @predicate = GreaterThan.new(operand_1, operand_2)
      end      
      
      describe "#to_arel" do
        it "returns an Arel::Where representation" do
          predicate.to_arel.should == Arel::GreaterThan.new(operand_1.to_arel, operand_2.to_arel)
        end
      end

      describe "#eval" do
        it "returns true if one of the operands is an attribute and its value in the tuple is > than the other operand" do
          predicate.eval(Account.new(:employee_id => operand_2 + 1)).should be_true
        end

        it "returns false if one of the operands is an attribute and its value in the tuple is not > than the other operand" do
          predicate.eval(Account.new(:employee_id => operand_2)).should be_false
        end

        context "when one of the operands is an AttributeSignal" do
          it "uses the value of the AttributeSignal in the predication" do
            tuple = Account.new(:employee_id => 1)
            GreaterThan.new(1, tuple.signal(:employee_id)).eval(tuple).should be_false
            GreaterThan.new(tuple.signal(:employee_id), 0).eval(tuple).should be_true
          end
        end
      end
    end
  end
end