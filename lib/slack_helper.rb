module SlackHelper
  def self.slack_sns_client
    @slack_sns_client ||= Aws::SNS::Client.new(region: slack_sns_region)
  end

  def self.slack_sns_publish(msg)
    slack_sns_client.publish(topic_arn: slack_sns_arn, message: msg.to_json)
  end

  def self.slack_sns_arn
    ENV["SLACK_SNS_TOPIC"].presence
  end

  def self.slack_sns_region
    match_data = slack_sns_arn.match(/arn:aws:sns:(?<region>.+):\d+:.+/) || {}
    match_data[:region] || ENV["AWS_REGION"].presence
  end

  def self.slack_channel
    ENV["SLACK_CHANNEL_ID"].presence
  end

  def send_slack(message, options = {})
    if SlackHelper.slack_sns_arn && SlackHelper.slack_channel
      SlackHelper.slack_sns_publish(slack_default_options.merge(options).merge(text: message))
    end
  end

  def slack_default_options
    {
      channel: SlackHelper.slack_channel || "#tech-dev-testing",
      username: "Dovetail Publishing",
      icon_emoji: ":radio:"
    }
  end
end
