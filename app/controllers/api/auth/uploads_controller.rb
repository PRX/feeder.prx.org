class Api::Auth::UploadsController < Api::BaseController
  include ApiAuthenticated

  before_action :authorize_uploading

  def self.s3_signer
    @s3_signer ||= Aws::S3::Presigner.new
  end

  def s3_signer
    self.class.s3_signer
  end

  def show
    opts = {bucket: s3_bucket, key: s3_key, use_accelerate_endpoint: s3_accelerate, expires_in: 30.minutes.to_i}
    exp = Time.now.to_i + opts[:expires_in]
    put_url = s3_signer.presigned_request(:put_object, opts)
    get_url = s3_signer.presigned_request(:get_object, opts)

    render json: {
      filename: s3_filename,
      accelerate: s3_accelerate,
      originalUrl: "s3://#{s3_bucket}/#{s3_key}",
      _links: {
        :self => {
          href: api_authorization_upload_path(filename: s3_filename, accelerate: s3_accelerate),
          profile: "http://#{ENV["META_HOST"]}/model/upload/auth"
        },
        :profile => {
          href: "http://#{ENV["META_HOST"]}/model/upload/auth"
        },
        "prx:upload" => {
          href: put_url.first,
          method: "PUT",
          expiration: exp
        },
        "prx:download" => {
          href: get_url.first,
          method: "GET",
          expiration: exp
        }
      }
    }
  end

  def authorize_uploading
    authorize MediaResource.new, :upload?
  end

  private

  def s3_bucket
    ENV["UPLOAD_BUCKET_NAME"]
  end

  def s3_key
    @s3_key ||= begin
      prefix = (ENV["UPLOAD_BUCKET_PREFIX"].presence || Rails.env).delete("/")
      [prefix, Date.utc_today, SecureRandom.uuid, s3_filename].compact.join("/")
    end
  end

  def s3_filename
    @filename ||= (params[:filename].presence || SecureRandom.uuid).gsub(/[^A-Za-z0-9\.\-]/, "_")
  end

  def s3_accelerate
    !!ActiveModel::Type::Boolean.new.cast(params[:accelerate])
  end

  # skip magical hal_api-rails stuff
  def resource_base
    nil
  end

  # no caching!
  def cache_show?
    false
  end
end
