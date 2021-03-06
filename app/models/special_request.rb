module Supplismo
  class SpecialRequest
    include DataMapper::Resource

    property :id, Serial
    property :text, String
    property :user_token, String
    property :ordered, Boolean, :default => false

  end
end
