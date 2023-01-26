class FeederFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_CLASS = "form-control"
  CHECK_CLASS = "form-check-input"
  SELECT_CLASS = "form-select"
  BLANK_CLASS = "form-control-blank"
  BLANK_ACTION = "blur->blank-field#blur"
  SEARCH_ACTION = "search#submit"
  SLIM_SELECT_CONTROLLER = "slim-select"
  FLATPICKR_CONTROLLER = "flatpickr"
  FLATPICKR_ACTION = "keydown->flatpickr#keydown keyup->flatpickr#keyup"
  SELECT_BY_GROUP = "slim-select-group-select-value"

  def text_field(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_disabled(options)
    super(method, options)
  end

  def text_area(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_disabled(options)
    super(method, options)
  end

  def number_field(method, options = {})
    options[:class] = INPUT_CLASS unless options.key?(:class)
    add_blank_class(options) if blank?(method, options)
    add_blank_action(options)
    add_disabled(options)
    super(method, options)
  end

  def check_box(method, options = {})
    options[:class] = CHECK_CLASS unless options.key?(:class)
    add_disabled(options)
    super(method, options)
  end

  def date_field(method, options = {})
    value = options[:value] || object&.public_send(method)
    options[:value] = value.try(:strftime, "%Y-%m-%d") || value

    add_flatpickr_controller(options)
    text_field(method, options)
  end

  def time_field(method, options = {})
    value = options[:value] || object&.public_send(method)

    # end timestamps are fudged 1-minute to look inclusive
    if options[:fudge] && value && value == value.beginning_of_day
      value -= 1.minute
    end
    options[:value] = value.try(:strftime, "%Y-%m-%d %H:%M") || value

    add_data(options, :fudge, true) if options[:fudge]
    add_data(options, :timestamp, true)
    add_flatpickr_controller(options)
    text_field(method, options)
  end

  def select(method, choices, options = {}, html_options = {}, &block)
    html_options[:class] = SELECT_CLASS unless html_options.key?(:class)
    add_blank_class(html_options) if blank?(method, options) && options[:include_blank]
    add_blank_action(html_options)
    add_slim_select_controller(html_options)
    add_disabled(html_options)
    add_select_by_group(html_options) if html_options[:group_select]
    super(method, choices, options, html_options, &block)
  end

  def search_text_field(method, params, options = {})
    value = options[:value] || params[method]
    text_field(method, add_search_action(options.merge(value: value)))
  end

  def search_date_field(method, params, options = {})
    value = options[:value] || params[method]
    date_field(method, add_search_action(options.merge(value: value)))
  end

  def search_time_field(method, params, options = {})
    value = options[:value] || params[method]
    time_field(method, add_search_action(options.merge(value: value)))
  end

  def search_check_box(method, params, options = {})
    checked = options[:checked] || params[method] == "1"
    check_box(method, add_search_action(options.merge(checked: checked)))
  end

  def search_select(method, choices, params, html_options = {})
    selected = html_options[:selected] || params[method]
    select(method, choices, {include_blank: true, selected: selected}, add_search_action(html_options))
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
    opts[:class] = [opts[:class], BLANK_CLASS].compact.join(" ").strip
  end

  def add_blank_action(opts)
    add_data(opts, :action, BLANK_ACTION)
  end

  def add_search_action(opts)
    add_data(opts, :action, SEARCH_ACTION)
  end

  def add_slim_select_controller(opts)
    add_data(opts, :controller, SLIM_SELECT_CONTROLLER)
  end

  def add_flatpickr_controller(opts)
    add_data(opts, :controller, FLATPICKR_CONTROLLER)
    add_data(opts, :action, FLATPICKR_ACTION)
  end

  def add_select_by_group(opts)
    add_data(opts, SELECT_BY_GROUP, opts[:group_select])
  end

  def add_disabled(opts)
    if !opts.key?(:disabled) && object && !@template.policy(object).create_or_update?
      opts[:disabled] = true
    end
  end

  def add_data(opts, key, val)
    opts ||= {}
    opts[:data] ||= {}
    opts[:data][key] = [opts[:data][key], val].compact.join(" ").strip.html_safe
    opts
  end
end
