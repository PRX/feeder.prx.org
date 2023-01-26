# frozen_string_literal: true

# this is real hacky ... but add an error class to error fields instead of
# wrapping them in a div that breaks bootstrap layouts
ActionView::Base.field_error_proc = proc do |html_tag, instance|
  feedback = ""
  if html_tag.match(/^<(input|textarea|select)/) && instance.error_message.present?
    msg = instance.error_message.join(", ").capitalize
    feedback = "<div class=\"invalid-feedback\">#{msg}</div>"
  end

  if html_tag.match?(/class="(.*?)"/)
    (html_tag.sub(/class="(.*?)"/, 'class="\1 is-invalid"') + feedback).html_safe
  else
    (html_tag.sub(/(\/>|>)/, 'class="is-invalid" \1') + feedback).html_safe
  end
end

# even more hacky! monkey patch to include association errors on the foreign key
# field, so a <select> gets the right error message
module ActiveModel
  class Errors
    def messages_for(attribute)
      if attribute.ends_with?("_id")
        m1 = where(attribute).map(&:message)
        m2 = where(attribute.to_s.sub(/_id$/, "")).map(&:message)
        m1.concat(m2).uniq
      else
        where(attribute).map(&:message)
      end
    end
  end
end
