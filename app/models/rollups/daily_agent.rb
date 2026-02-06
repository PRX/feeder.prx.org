class Rollups::DailyAgent < ActiveRecord::Base
  establish_connection :clickhouse

  LABELS =
    begin
      agents_lock_pathname = Rails.root.join("vendor/agents.lock.yml")
      if File.exist?(agents_lock_pathname)
        db = YAML.load_file(agents_lock_pathname)
        agent_codes = db["agents"]
          .map { |v| [v["os"], v["name"], v["type"]] }
          .flatten
          .compact
          .uniq
        agent_label_lookup = agent_codes.map { |code| [db["tags"][code], code] }.to_h
        agent_label_lookup.invert.freeze
      else
        message = "Missing the vendor/agents.lock.yml file from prx-podagents\n"
        message += "Agent labels will be mangled until you download it!!"
        Rails.logger.error(msg: message)
        {}
      end
    end

  def self.label_for(code)
    LABELS[code.to_s] || unknown_code(code)
  end

  def self.code_for(label)
    LABELS.key(label) || label
  end

  def self.unknown_code(code)
    if code != :other
      "Unknown"
    else
      "Other"
    end
  end
end
