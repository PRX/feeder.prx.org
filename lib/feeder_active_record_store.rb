# customized AR-store, which doesn't run SQL on API requests
class FeederActiveRecordStore < ActionDispatch::Session::ActiveRecordStore
  def find_session(request, id)
    # id gets set from non request.session_options[:skip] controllers
    super unless id.nil?
  end
end
