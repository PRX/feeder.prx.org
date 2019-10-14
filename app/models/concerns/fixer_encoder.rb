require 'active_support/concern'

module FixerEncoder
  extend ActiveSupport::Concern

  class_methods do
    def new_fixer_sqs_client
      Fixer::SqsClient.new
    end
  end

  def fixer_start!(opts)
    opts = (opts || {}).with_indifferent_access
    task = {
      task_type: 'copy',
      result: fixer_destination(opts[:destination]),
      call_back: opts[:callback]
    }
    job = {
      job_type: opts[:job_type],
      original: opts[:source],
      tasks: [ task ],
      priority: 1,
      retry_delay: 300,
      retry_max: 12
    }
    msg = fixer_sqs_client.create_job(job: job)
    msg[:job][:id]
  end

  def fixer_destination(dest)
    parsed = URI.parse(dest)
    URI::Generic.build(
      scheme: parsed.scheme,
      host: parsed.host,
      path: parsed.path,
      query: fixer_query
    ).to_s
  rescue URI::InvalidURIError
    dest
  end

  def fixer_query(params = {})
    max_age = ENV['FIXER_CACHE_MAX_AGE'].present? ? ENV['FIXER_CACHE_MAX_AGE'] : 86400
    defaults = {
      'x-fixer-public' => 'true',
      'x-fixer-Cache-Control' => "max-age=#{max_age}"
    }
    URI.encode_www_form(defaults.merge(params))
  end

  private

  def fixer_sqs_client
    @fixer_sqs_client ||= self.class.new_fixer_sqs_client
  end

  def fixer_sqs_client=(client)
    @fixer_sqs_client = client
  end
end
