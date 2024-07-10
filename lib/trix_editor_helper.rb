# modified from:
# https://github.com/afomera/trix/blob/ea25b97a0fcb7c17dba6199e353ad14f2232beed/lib/trix/form.rb

require "action_view"
require "active_support/core_ext"

module TrixEditorHelper
  mattr_accessor(:id, instance_accessor: false)
  class_variable_set(:@@id, 0)

  def trix_editor_tag(name, value = nil, options = {})
    options.symbolize_keys!

    # handle disabled fields
    toolbar_tag = ""
    if options[:disabled]
      options[:contentEditable] = false
      options[:toolbar] = "trix-blank-toolbar_#{name}"
      toolbar_tag = content_tag(:div, nil, id: options[:toolbar])
    end

    css_class = Array.wrap(options.delete(:class)).join(" ")
    attributes = {
      class: "formatted_content trix-content #{css_class}".squish,
      input: "trix_input_#{TrixEditorHelper.id += 1}"
    }.merge(options)

    editor_tag = content_tag("trix-editor", "", attributes)
    input_tag = hidden_field_tag(name, value, options.merge(id: attributes[:input], class: "trix-hidden-field"))

    input_tag + editor_tag + toolbar_tag
  end
end

module ActionView
  module Helpers
    include TrixEditorHelper

    module Tags
      class TrixEditor < Base
        include TrixEditorHelper
        delegate :dom_id, to: :@template_object

        def render
          options = @options.stringify_keys
          add_default_name_and_id(options)
          options["input"] ||= dom_id(object, [options["id"], :trix_input].compact.join("_"))

          value = if Rails.gem_version >= Gem::Version.new("5.2.x")
            options.delete("value") { value_before_type_cast }
          else
            value_before_type_cast(object)
          end

          trix_editor_tag(options.delete("name"), value, options)
        end
      end
    end

    module FormHelper
      def trix_editor(object_name, method, options = {})
        Tags::TrixEditor.new(object_name, method, self, options).render
      end
    end

    class FormBuilder
      def trix_editor(method, options = {})
        @template.trix_editor(@object_name, method, objectify_options(options))
      end
    end
  end
end
