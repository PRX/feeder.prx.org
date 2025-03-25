class FeederFormBuilder < ActionView::Helpers::FormBuilder
  alias_method :super_select, :select

  INPUT_CLASS = "form-control"
  CHECK_CLASS = "form-check-input"
  SELECT_CLASS = "form-select"
  BLANK_CLASS = "form-control-blank"
  BLANK_ACTION = "blur->blank-field#blur"
  CHANGED_CLASS = "is-changed"
  CHANGED_ACTION = "change->unsaved#change keyup->unsaved#change"
  CHANGED_DATA_VALUE_WAS = :value_was
  SEARCH_ACTION = "search#submit"
  SLIM_SELECT_CONTROLLER = "slim-select"
  TAG_SELECT_CONTROLLER = "tag-select"
  FLATPICKR_CONTROLLER = "flatpickr"
  FLATPICKR_ACTION = "flatpickr#change"
  SELECT_BY_GROUP = "slim-select-group-select-value"
  TIME_ZONE_CONTROLLER = "time-zone"

  IMPORTANT_ZONES = [
    "Hawaii",
    "Alaska",
    "Pacific Time (US & Canada)",
    "Mountain Time (US & Canada)",
    "Central Time (US & Canada)",
    "Eastern Time (US & Canada)",
    "UTC"
  ]

  def text_field(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_changed(method, options)
    add_disabled(options)
    redact_value(method, options)
    super
  end

  def redact_value(method, options)
    d = options[:disabled] || disabled?
    return unless options[:redacted] && d

    if (val = object.public_send(method))
      chars = [options[:redacted].to_i, 1].max
      options[:value] = val.last(chars).rjust(val.length, "*")
    end
  end

  def text_area(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_changed(method, options)
    add_disabled(options)
    super
  end

  def number_field(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_changed(method, options)
    add_disabled(options)
    super
  end

  def check_box(method, options = {})
    options[:class] = CHECK_CLASS unless options.key?(:class)
    add_changed(method, options)
    add_disabled(options)
    super
  end

  def date_field(method, options = {})
    add_flatpickr_controller(options)
    text_field(method, options)
  end

  def time_zone_field(method, options = {})
    add_data(options, :controller, TIME_ZONE_CONTROLLER)
    select method, IMPORTANT_ZONES, {selected: "UTC"}, options
  end

  def select(method, choices, options = {}, html_options = {}, &block)
    html_options[:class] = SELECT_CLASS unless html_options.key?(:class)
    add_blank_class(html_options) if blank?(method, options) && options[:include_blank]
    add_blank_action(html_options)
    add_changed(method, html_options)
    add_slim_select_controller(html_options)
    add_disabled(html_options)
    add_select_by_group(html_options) if html_options[:group_select]
    super
  end

  def tag_select(method, choices, options = {}, html_options = {}, &block)
    options[:include_blank] = true
    html_options[:class] = SELECT_CLASS unless html_options.key?(:class)
    html_options[:multiple] = true
    add_blank_class(html_options) if blank?(method, options)
    add_blank_action(html_options)
    add_tag_select_controller(html_options)
    add_disabled(html_options)
    super_select(method, choices, options, html_options, &block)
  end

  def search_text_field(method, params, options = {})
    value = options[:value] || params[method]
    text_field(method, add_search_action(options.merge(value: value)))
  end

  def search_date_field(method, params, options = {})
    value = options[:value] || params[method]
    date_field(method, add_search_action(options.merge(value: value)))
  end

  def search_check_box(method, params, options = {})
    checked = options[:checked] || params[method] == "1"
    check_box(method, add_search_action(options.merge(checked: checked)))
  end

  def search_select(method, choices, params, html_options = {})
    selected = html_options[:selected] || params[method]
    select(method, choices, {include_blank: true, selected: selected}, add_search_action(html_options))
  end

  def trix_editor(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_changed(method, options)
    add_disabled(options)
    super
  end

  def disabled?
    object && !@template.policy(object).create_or_update?
  end

  private

  def blank?(method, opts)
    if opts.key?(:value)
      opts[:value].blank?
    elsif opts.key?(:selected)
      opts[:selected].blank?
    elsif object.present?
      object.public_send(method).blank?
    else
      true
    end
  end

  def add_blank_class(opts)
    add_class(opts, BLANK_CLASS)
  end

  def add_blank_action(opts)
    add_data(opts, :action, BLANK_ACTION)
  end

  def add_changed(method, opts)
    add_data(opts, :action, CHANGED_ACTION)

    if object.present?
      changed = object.try("#{method}_changed?")
      has_value_was = object.respond_to?(:"#{method}_was")
      value_was = object.try("#{method}_was")
      value_is = object.try(method)

      # add changed class to changed fields
      if changed
        # but ignore nils being set to blanks by text fields
        if has_value_was && value_was.nil? && value_is == ""
          return
        else
          add_class(opts, CHANGED_CLASS)
        end
      end

      # save previous value as a data attribute
      if has_value_was
        opts[:data][CHANGED_DATA_VALUE_WAS] = value_was.to_s.html_safe
      end
    end
  end

  def add_search_action(opts)
    add_data(opts, :action, SEARCH_ACTION)
  end

  def add_slim_select_controller(opts)
    add_data(opts, :controller, SLIM_SELECT_CONTROLLER)
  end

  def add_tag_select_controller(opts)
    add_data(opts, :controller, TAG_SELECT_CONTROLLER)
  end

  def add_flatpickr_controller(opts)
    add_data(opts, :controller, FLATPICKR_CONTROLLER)
    add_data(opts, :action, FLATPICKR_ACTION)
  end

  def add_select_by_group(opts)
    add_data(opts, SELECT_BY_GROUP, opts[:group_select])
  end

  def add_disabled(opts)
    if !opts.key?(:disabled) && disabled?
      opts[:disabled] = true
    end
  end

  def add_class(opts, cls)
    opts[:class] = [opts[:class], cls].compact.join(" ").strip
  end

  def add_data(opts, key, val)
    opts ||= {}
    opts[:data] ||= {}
    opts[:data][key] = [val, opts[:data][key]].compact.join(" ").strip.html_safe
    opts
  end
end
