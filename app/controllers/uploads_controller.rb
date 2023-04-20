class UploadsController < ApplicationController
  # GET /uploads/signature
  def signature
    date_stamp = Date.strptime(params[:datetime], "%Y%m%dT%H%M%SZ").strftime("%Y%m%d")

    date_key = OpenSSL::HMAC.digest("sha256", "AWS4" + secret_key, date_stamp)
    region_key = OpenSSL::HMAC.digest("sha256", date_key, aws_region)
    service_key = OpenSSL::HMAC.digest("sha256", region_key, "s3")
    signing_key = OpenSSL::HMAC.digest("sha256", service_key, "aws4_request")

    render plain: OpenSSL::HMAC.hexdigest("sha256", signing_key, params[:to_sign]).delete("\n")
  end

  private

  # allow signing uploads locally in dev only
  def secret_key
    Aws::CredentialProviderChain.new.resolve.credentials.secret_access_key if Rails.env.development?
  end

  def aws_region
    if ENV["AWS_REGION"].present?
      ENV["AWS_REGION"]
    else
      "us-east-1"
    end
  end
end
