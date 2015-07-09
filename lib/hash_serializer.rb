class HashSerializer
  def self.dump(obj)
    ActiveSupport::JSON.encode(obj)
  end

  def self.load(json)
    if !json.nil?
      ActiveSupport::JSON.decode(json).try(:with_indifferent_access)
    end
  end
end
