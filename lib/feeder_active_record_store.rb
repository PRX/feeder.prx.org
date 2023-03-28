# customized AR-store, which doesn't run SQL on API requests
class FeederActiveRecordStore < ActionDispatch::Session::ActiveRecordStore
  def find_session(request, id)
    # TODO: how to determine if request.session_options[:skip], before that before_action has even run?
    # or just check request path?
    # or a controller class method/var?
    # binding.pry
    # then return nil instead of super
    super
  end
end
