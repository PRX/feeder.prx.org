module UploadsHelper
  def uploads_meta_tags
    [
      tag(:meta, name: :upload_bucket_name, content: ENV["UPLOAD_BUCKET_NAME"]),
      tag(:meta, name: :upload_bucket_prefix, content: uploads_prefix),
      tag(:meta, name: :upload_s3_endpoint_host, content: ENV["UPLOAD_S3_ENDPOINT_HOST"]),
      tag(:meta, name: :upload_signing_service_key_id, content: uploads_key_id),
      tag(:meta, name: :upload_signing_service_url, content: uploads_service_url)
    ].join("\n    ").html_safe
  end

  def uploads_destroy_params(form1, form2 = nil)
    params = {}
    params["#{form1.object_name}[id]"] = form1.object.id
    params["#{form2.object_name}[id]"] = form2.object.id if form2

    # destroy only the right-most form object
    if form2
      params["#{form2.object_name}[_destroy]"] = "1"
    else
      params["#{form1.object_name}[_destroy]"] = "1"
    end

    params
  end

  private

  def uploads_prefix
    if ENV["UPLOAD_BUCKET_PREFIX"].present?
      ENV["UPLOAD_BUCKET_PREFIX"]
    else
      Rails.env
    end
  end

  def uploads_key_id
    if ENV["UPLOAD_SIGNING_SERVICE_KEY_ID"].present?
      ENV["UPLOAD_SIGNING_SERVICE_KEY_ID"]
    elsif Rails.env.development? && ENV["UPLOAD_BUCKET_NAME"].present?
      uploads_resolve_dev_credentials
    end
  end

  def uploads_service_url
    if ENV["UPLOAD_SIGNING_SERVICE_URL"].present?
      ENV["UPLOAD_SIGNING_SERVICE_URL"]
    elsif Rails.env.development?
      main_app.uploads_signature_path
    end
  end

  def uploads_resolve_dev_credentials
    Aws::CredentialProviderChain.new.resolve.credentials.access_key_id
  rescue Aws::STS::Errors::AccessDenied => e
    if e.message.include?("MultiFactorAuthentication failed")

      # prompt for code
      config = Aws.shared_config
      puts "\n\n\n#{"MultiFactorAuthentication REQUIRED!".red}"
      puts "\n\nEnter MFA code for #{config.profile_name}:\n\n>".green
      code = $stdin.getpass

      # fetch and set temporary credentials (60 minutes)
      opts = {token_code: code.strip, duration_seconds: 3600}
      creds = config.assume_role_credentials_from_config(opts).credentials

      ENV["AWS_ACCESS_KEY_ID"] = creds.access_key_id
      ENV["AWS_SECRET_ACCESS_KEY"] = creds.secret_access_key
      ENV["AWS_SESSION_TOKEN"] = creds.session_token

      creds.access_key_id
    else
      raise e
    end
  end
end
