class Api::FeedTokenRepresenter < Roar::Decorator
  include Roar::JSON

  property :label
  property :token
  property :expires_at, as: :expires
end
