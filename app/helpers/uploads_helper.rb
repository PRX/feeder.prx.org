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
    elsif ENV["AWS_ACCESS_KEY_ID"].present?
      ENV["AWS_ACCESS_KEY_ID"]
    elsif Rails.env.development?
      # allow signing uploads locally in dev only
      Aws::S3::Client.new.config.credentials.credentials.access_key_id
    end
  end

  def uploads_service_url
    if ENV["UPLOAD_SIGNING_SERVICE_URL"].present?
      ENV["UPLOAD_SIGNING_SERVICE_URL"]
    elsif Rails.env.development?
      uploads_signature_path
    end
  end
end
