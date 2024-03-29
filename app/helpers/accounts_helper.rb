module AccountsHelper
  def podcast_account_name_options(podcast)
    if podcast.new_record?
      account_name_options(:podcast_create, podcast.prx_account_uri)
    else
      account_name_options(:podcast_edit, podcast.prx_account_uri)
    end
  end

  def account_name_options(scope, selected_uri = nil)
    account_ids = current_user.authorized_account_ids(scope)

    # ensure the selected uri always has a display value
    if selected_uri
      selected_id = URI.parse(selected_uri).path.split("/").last.to_i
      account_ids << selected_id if selected_id.present? && account_ids.exclude?(selected_id)
    end

    account_uris = account_ids.map { |id| "/api/v1/accounts/#{id}" }
    account_ids.map { |id| account_name_for(id) }.zip(account_uris).sort
  end
end
