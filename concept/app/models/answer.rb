module Models
  class Answer < Unison::Tuple::Base
    # automate this for the default case
    member_of Relations::Set.new(:answers)

    attribute :id
    attribute :question_id
    attribute :body

    relates_to_one :question do
      Question.where(Question[:id].eq(self[:question_id]))
    end
  end
end