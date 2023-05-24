require "aws-sdk-core"

namespace :sqs do
  desc "Create required SQS queues"
  task :create, [:env] do
    sqs = Aws::SQS::Client.new
    names = Rails.application.config_for(:shoryuken, env: :queues).map(&:first)
    group_names = Rails.application.config_for(:shoryuken, env: :groups).values.map { |v| v[:queues] }.map { |config| config.map(&:first) }.flatten
    names += group_names

    # only allow creating queues in dev, with non-default names
    abort "Can only create queues in development" unless Rails.env.development?
    abort "You must set an ANNOUNCE_RESOURCE_PREFIX" if names.first.starts_with?("development")

    default_options = {
      "DelaySeconds" => "0",
      "MaximumMessageSize" => (256 * 1024).to_s,
      "VisibilityTimeout" => 1.hour.seconds.to_i.to_s,
      "ReceiveMessageWaitTimeSeconds" => "0",
      "MessageRetentionPeriod" => 1.week.seconds.to_i.to_s
    }

    names.each do |name|
      q = sqs.create_queue(queue_name: name, attributes: default_options)
      url = q.queue_url
      puts "created queue: #{url}"

      if name.ends_with?("callback")
        resp = sqs.get_queue_attributes(queue_url: url, attribute_names: ["All"])

        porter_policy = {
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Allow",
              Principal: {
                AWS: "arn:aws:iam::561178107736:root"
              },
              Action: "sqs:SendMessage",
              Resource: resp.attributes["QueueArn"]
            }
          ]
        }.to_json

        if resp.attributes["Policy"] != porter_policy
          sqs.set_queue_attributes(queue_url: url, attributes: {"Policy" => porter_policy})
          puts "set queue policy on: #{url}"
        end
      end
    end
  end
end
