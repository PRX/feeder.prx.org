require 'roar/rails/responder'

class Api::ApiResponder < Roar::Rails::Responder
  def api_behavior
    raise MissingRenderer.new(format) unless has_renderer?

    if post?
      display(resource, status: :created)
    elsif put?
      display(resource, status: :ok)
    elsif delete?
      display(resource, status: :no_content)
    else
      super
    end
  end
end
