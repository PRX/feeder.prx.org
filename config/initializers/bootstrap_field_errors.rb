# frozen_string_literal: true

# this is real hacky ... but add an error class to error fields instead of
# wrapping them in a div that breaks bootstrap layouts
ActionView::Base.field_error_proc = proc do |html_tag, instance|
  feedback = ""
  if html_tag.match(/^<(input|textarea|select|trix-editor)/) && instance.error_message.present?
    msg = instance.error_message.join(", ").capitalize
    feedback = "<div class=\"invalid-feedback\">#{msg}</div>"
  end

  if html_tag.match?(/class="(.*?)"/)
    (html_tag.sub(/class="(.*?)"/, 'class="\1 is-invalid"') + feedback).html_safe
  else
    (html_tag.sub(/^(<[^ ]+) /, '\1 class="is-invalid" ') + feedback).html_safe
  end
end

# even more hacky! monkey patch to include error messages from other fields.
module ActiveModel
  class Errors
    def messages_for(attribute)
      to_check = [attribute]

      # include association errors on the foreign key field
      if attribute.ends_with?("_id")
        to_check << attribute.to_s.sub(/_id\z/, "")
      end

      # include aliased attributes
      if @base.attribute_aliases.key?(attribute.to_s)
        to_check << @base.attribute_aliases[attribute.to_s]
      end

      # include aliased error messages
      if @base.error_message_aliases.key?(attribute.to_s)
        to_check << @base.error_message_aliases[attribute.to_s]
      end

      to_check.map { |a| where(a).map(&:message) }.flatten.uniq
    end
  end
end
