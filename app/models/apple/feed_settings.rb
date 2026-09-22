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
  # - hls_enabled: whether a public feed's binding delivers HLS video
  #
  # Every attribute is optional. A missing one keeps the saved setting, so
  # a form that doesn't render a field can't clear it.
  #
  # The feed saves them with its own changes:
  #
  #   feed.update(apple_settings: {connection: "6813172774", delivery: "own"})
  class FeedSettings
    include ActiveModel::Model

    OWN = "own"
    ATTRIBUTES = %i[delivery connection publish_enabled sync_blocks_rss hls_enabled].freeze
    BOOLEANS = %i[publish_enabled sync_blocks_rss hls_enabled].freeze

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

    def hls_enabled_was
      !!hls_config&.enabled?
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

    # HLS video is delivered through a public feed's own binding.
    def hls_available?
      connectable? && feed.public?
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

    # Saving this delivery removes the feed's connection. A private feed's
    # connection only serves its own show. A public feed's goes when it maps
    # to another feed or its delivery is removed, but not when it just stays
    # without delivery, since other feeds may deliver through its show.
    def disconnects?
      deliverable? && !own_show? && (feed.private? || delivery.present? || delivery_changed?)
    end

    # Leaving a private feed's own show removes its connection on save.
    def confirm_leaving_own_show?
      delivery_was == OWN && feed.private? && binding.present?
    end

    # The mappable binding a delivery id names. Any other id, such as another
    # podcast's binding, a private feed's, or one another feed delivers
    # through, finds nothing, so validation reports it on the delivery.
    def mapped_binding
      mappable_bindings.find { |binding| binding.id == mapped_binding_id } if mapped_binding_id
    end

    # Other feeds' bindings this feed can map to. The saved mapping stays
    # selectable so a save doesn't clear it when its feed is no longer
    # available.
    def mappable_bindings
      @mappable_bindings ||= Apple::ShowFeedBinding.available_for_delivery(feed).where.not(feed_id: feed.id).to_a |
        [saved_mapped_binding].compact
    end

    def binding
      feed.apple_show_feed_binding
    end

    def config
      feed.delegated_delivery_config
    end

    def hls_config
      binding&.hls_config
    end

    # Point the feed's config at the submitted delivery before the feed
    # validates. The config saves with the feed.
    def apply
      return if @applied

      @applied = true
      apply_delivery
    end

    # Connect before the feed saves so its config can select a new binding.
    # The feed calls this inside its save transaction, after validation and
    # before any write, so an invalid feed never reads the show from Apple
    # and a failed read leaves nothing to roll back.
    def connect
      return true unless connection_change == :connect

      connection_changed(connection_binding.connect_existing(connection))
    end

    # Disconnect after the feed saves so its config no longer selects the
    # binding.
    def disconnect
      return true unless connection_change == :disconnect

      connection_changed(binding.disconnect)
    end

    # Save HLS after the feed saves and after disconnect, so a disconnected
    # binding takes its HLS config with it.
    #
    # Enabling HLS, or reconnecting while enabled, rechecks Apple video
    # eligibility. Disabling makes no Apple request and leaves Apple video as is.
    def save_hls_config
      return true unless hls_submitted?

      if binding.nil?
        return true if !hls_enabled || connection_change

        errors.add(:hls_enabled, "HLS video requires an Apple show connection")
        return false
      end

      hls = binding.hls_config || binding.build_hls_config
      return true if hls.new_record? && !hls_enabled

      recheck = hls_enabled && (!hls.enabled? || connection_change)
      hls.enabled = hls_enabled
      return false if recheck && !refresh_hls_eligibility(hls)

      hls.save!
      true
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

    def hls_submitted?
      hls_available? && submitted?(:hls_enabled)
    end

    def mapped_binding_id
      delivery.to_i if delivery.match?(/\A\d+\z/)
    end

    # The other feed's binding the saved config points at. Read from the
    # database, since applying a delivery repoints the config in memory.
    def saved_mapped_binding
      saved_id = config&.show_feed_binding_id_in_database
      return if saved_id.nil? || saved_id == binding&.id

      Apple::ShowFeedBinding.includes(:feed).find_by(id: saved_id)
    end

    # Point the feed's config at the submitted binding, or remove it. The
    # config saves with the feed. Read disconnects? first, since pointing the
    # config changes the saved delivery it compares against.
    def apply_delivery
      if delivery_submitted?
        disconnect = disconnects?

        if delivery.blank?
          config&.mark_for_destruction
        elsif own_show?
          point_config_at(connection_binding) if connection.present? && !binding&.other_feed_config
        elsif mapped_binding
          point_config_at(mapped_binding)
        end

        @submitted[:connection] = "" if disconnect
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
        elsif (other = binding&.other_feed_config)
          label = other.feed&.label || "another feed"
          errors.add(:connection, "is already used for delegated delivery by #{label}. Map that feed to a different public feed before publishing this feed to its own Apple show")
        end
      elsif delivery.present? && !mapped_binding
        errors.add(:delivery, "must be this feed's own Apple show or a public feed on this podcast")
      end
    end

    def connection_change
      return unless connectable? && connection_changed?

      connection.present? ? :connect : :disconnect
    end

    def connection_binding
      @connection_binding ||= binding || Apple::ShowFeedBinding.new(feed: feed)
    end

    def connection_changed(binding)
      binding.errors.full_messages.each { |message| errors.add(:connection, message) }
      return false if binding.errors.any?

      feed.association(:apple_show_feed_binding).reset
      @connection_binding = nil
      true
    end

    def refresh_hls_eligibility(hls)
      hls.refresh_eligibility
      true
    rescue => error
      Rails.logger.error("Unable to check Apple HLS eligibility", feed_id: feed.id, apple_show_id: binding.apple_show_id, error: error)
      errors.add(:hls_enabled, "Could not check Apple video eligibility for this show")
      false
    end
  end
end
