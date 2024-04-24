module SlackHelper
  def self.slack_eventbridge_client
    @slack_eventbridge_client ||= Aws::EventBridge::Client.new
  end

  def self.slack_event_send(msg)
    slack_eventbridge_client.put_events({
      entries: [
        {
          source: "org.prx.feeder",
          detail_type: "Slack Message Relay Message Payload",
          detail: msg.to_json
        }
      ]
    })
  end

  def self.slack_channel
    ENV["SLACK_CHANNEL_ID"].presence
  end

  def send_slack(message, options = {})
    if SlackHelper.slack_channel
      SlackHelper.slack_event_send(slack_default_options.merge(options).merge(text: message))
    end
  end

  def slack_default_options
    test_channel_id = "C06G0QM1U8Z"

    {
      channel: SlackHelper.slack_channel || test_channel_id,
      username: "Dovetail Podcasts",
      icon_emoji: ":radio:"
    }
  end
end
