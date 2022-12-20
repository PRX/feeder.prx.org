# frozen_string_literal: true

class FeederLogger < Ougai::Logger
  include ActiveSupport::LoggerThreadSafeLevel
  include ActiveSupport::LoggerSilence

  def create_formatter
    if Rails.env.development? || Rails.env.test?
      color_config = Ougai::Formatters::Colors::Configuration.new
      formatter = Ougai::Formatters::Customizable.new(
        format_msg: proc do |severity, datetime, _progname, data|
          format(
            '%<severity>s %<datetime>s: %<msg>s %<data>s',
            severity: color_config.color(:severity, severity, severity),
            datetime: color_config.color(:datetime, datetime, severity),
            msg: color_config.color(:msg, data.delete(:msg).try(:squish), severity),
            data: data.ai(multiline: false)
          )
        end,
        # this appears to be redundant with format_msg, so just no-op
        format_data: proc { |_data| nil }
      )
      formatter.datetime_format = '%H:%M:%S.%L'
      formatter
    else
      Ougai::Formatters::Bunyan.new
    end
  end

  def elapsed(msg = '', args = {}, &block)
    measure(:info, msg, args, &block)
  end

  def debug_elapsed(msg = '', args = {}, &block)
    measure(:debug, msg, args, &block)
  end

  private

  def measure(level, msg, args, &block)
    elapsed = Benchmark.measure(&block)
    if msg.is_a? Hash
      public_send(level, msg.merge(elapsed: elapsed.real))
    else
      public_send(level, msg, args.merge(elapsed: elapsed.real))
    end
  end
end
