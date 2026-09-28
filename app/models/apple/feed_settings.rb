# frozen_string_literal: true

module Apple
  # A feed's Apple settings as edited on the feed form, shaped like the
  # records they save:
  #
  # - connection: this feed's Apple show (its ShowFeedBinding); blank for none
  # - delivery: where its delegated delivery config points; blank for no
  #   config, OWN for this feed's own binding (which may not exist until
  #   this save connects it), or the id of a public feed's binding
  # - publish_enabled, sync_blocks_rss: the delivery config's flags
  #
  # Every attribute is optional. A missing one keeps the saved setting, so
  # a form that doesn't render a field can't clear it.
  #
  #   settings = Apple::FeedSettings.new(feed, connection: "6813172774", delivery: "own")
  #   settings.save # saves the feed and its Apple records together
  class FeedSettings
    include ActiveModel::Model

    OWN = "own"
    ATTRIBUTES = %i[delivery connection publish_enabled sync_blocks_rss].freeze
    BOOLEANS = %i[publish_enabled sync_blocks_rss].freeze

    attr_reader :feed

    validate :delivery_requirements, if: :delivery_submitted?

    def initialize(feed, attributes = {})
      @feed = feed
      @submitted = attributes.to_h.symbolize_keys.slice(*ATTRIBUTES)
    end

    # Field errors look for aliases on their model (bootstrap_field_errors.rb).
    def attribute_aliases
      {}
    end

    def error_message_aliases
      {}
    end

    ATTRIBUTES.each do |name|
      define_method(name) { submitted?(name) ? cast(name, @submitted[name]) : public_send(:"#{name}_was") }
      define_method(:"#{name}_changed?") { submitted?(name) && public_send(name) != public_send(:"#{name}_was") }
    end

    # Kept from the first read: preparing a connection edits the saved binding.
    def connection_was
      @connection_was ||= binding&.apple_show_id.to_s
    end

    # A private feed's connection only serves its own show, so one without a
    # config still delivers there.
    def delivery_was
      if config.nil?
        (binding && feed.private?) ? OWN : ""
      elsif binding && config.show_feed_binding_id == binding.id
        OWN
      else
        config.show_feed_binding_id.to_s
      end
    end

    def publish_enabled_was
      !!config&.publish_enabled?
    end

    def sync_blocks_rss_was
      !!config&.sync_blocks_rss?
    end

    # Megaphone feeds deliver to Apple without an Apple show connection.
    def connectable?
      feed.apple_connectable?
    end

    # The default feed is what other feeds deliver through, so it has no
    # delivery of its own.
    def deliverable?
      connectable? && !feed.default?
    end

    # A new feed maps to a public feed; its own show is set up once saved.
    def own_available?
      feed.persisted?
    end

    def delivering?
      delivery.present?
    end

    def own_show?
      delivery == OWN
    end

    # The shorthand the form shows sections by: none, own or mapped.
    def route
      return "none" if delivery.blank?

      own_show? ? "own" : "mapped"
    end

    # Leaving a private feed's own show removes its connection on save.
    def confirm_leaving_own_show?
      delivery_was == OWN && feed.private? && binding.present?
    end

    # The public feed binding a delivery id names. It's looked up within the
    # podcast, so a submitted id can't reveal another podcast's feed.
    def mapping
      return unless mapping_id

      @mapping = nil unless @mapping&.id == mapping_id
      @mapping ||= Apple::ShowFeedBinding.joins(:feed).includes(:feed)
        .where(feeds: {podcast_id: feed.podcast_id}).where.not(feed_id: feed.id).find_by(id: mapping_id)
    end

    def mapped_show_id
      mapping&.apple_show_id
    end

    # Bindings this feed can map to. The current mapping stays selectable so
    # a save doesn't clear it when its feed is no longer available.
    def mapping_bindings
      @mapping_bindings ||= begin
        bindings = Apple::ShowFeedBinding.available_for_delivery(feed).where.not(feed_id: feed.id).to_a
        current = mapping
        bindings << current if current && bindings.exclude?(current)
        bindings
      end
    end

    def binding
      feed.apple_show_feed_binding
    end

    def config
      feed.delegated_delivery_config
    end

    def save
      apply_delivery
      settings_valid = valid?
      return false unless feed.valid? && settings_valid

      return feed.save if connection_change.nil?

      # Read the show before the transaction locks the feed row.
      return false if connection_change == :connect && !prepare_connection

      # Connect before saving so delivery can select a new binding, and
      # disconnect after saving so delivery no longer selects it.
      saved = false
      feed.transaction do
        saved = (connection_change != :connect || update_connection) && feed.save &&
          (connection_change != :disconnect || update_connection)
        raise ActiveRecord::Rollback unless saved
      end
      saved
    end

    private

    def submitted?(name)
      @submitted.key?(name)
    end

    def cast(name, value)
      BOOLEANS.include?(name) ? !!ActiveModel::Type::Boolean.new.cast(value) : value.to_s
    end

    def delivery_submitted?
      deliverable? && submitted?(:delivery)
    end

    def mapping_id
      delivery.to_i if delivery.match?(/\A\d+\z/)
    end

    # Point the feed's config at the submitted binding, or remove it. The
    # config saves with the feed. A private feed's connection only serves its
    # own show, so any other delivery disconnects it.
    def apply_delivery
      if delivery_submitted?
        if delivery.blank?
          config&.mark_for_destruction
        elsif own_show?
          point_config_at(connection_binding) if connection.present? && !own_show_taken_by
        elsif mapping
          point_config_at(mapping)
        end

        @submitted[:connection] = "" if feed.private? && !own_show?
      end

      apply_config_flags
    end

    def point_config_at(binding)
      config = self.config || feed.build_delegated_delivery_config
      config.show_feed_binding = binding unless binding.persisted? && config.show_feed_binding_id == binding.id
    end

    def apply_config_flags
      return if config.nil? || config.marked_for_destruction?

      config.publish_enabled = publish_enabled if submitted?(:publish_enabled)
      config.sync_blocks_rss = sync_blocks_rss if submitted?(:sync_blocks_rss)
    end

    def delivery_requirements
      if own_show?
        if connection.blank?
          errors.add(:connection, "must be selected to publish to this feed's own Apple show")
        elsif (other = own_show_taken_by)
          label = other.feed&.label || "another feed"
          errors.add(:connection, "is already used for delegated delivery by #{label}. Map that feed to a different public feed before publishing this feed to its own Apple show")
        end
      elsif delivery.present? && !mapping
        errors.add(:delivery, "must be this feed's own Apple show or a public feed on this podcast")
      end
    end

    # Another feed already delivers through this feed's Apple show.
    def own_show_taken_by
      return unless binding&.persisted?

      Apple::DelegatedDeliveryConfig.where(show_feed_binding_id: binding.id).where.not(feed_id: feed.id).includes(:feed).first
    end

    def connection_change
      return unless connectable? && connection_changed?

      connection.present? ? :connect : :disconnect
    end

    def connection_binding
      @connection_binding ||= binding || Apple::ShowFeedBinding.new(feed: feed)
    end

    def prepare_connection
      connection_binding.prepare_connection(connection)
      copy_errors(connection_binding)
    end

    def update_connection
      if connection_change == :connect
        connection_binding.connect!
      else
        binding.association(:delegated_delivery_config).reset
        binding.destroy
      end
      return false unless copy_errors(connection_binding)

      feed.association(:apple_show_feed_binding).reset
      @connection_binding = nil
      true
    end

    def copy_errors(record)
      record.errors.full_messages.each { |message| errors.add(:connection, message) }
      record.errors.empty?
    end
  end
end
