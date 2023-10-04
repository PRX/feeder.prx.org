# various helpers for searching via query params on index pages
module SearchHelper
  def search_button(label, name, value)
    opts = {
      type: "button",
      class: "dropdown-item text-decoration-none",
      name: name,
      data: {action: "dynamic-form#change"},
      value: value
    }

    if params[name] == value || (params[name].blank? && value.blank?)
      opts[:class] += " active"
      opts[:aria] = {current: "page"}
    end

    button_tag(label, opts)
  end

  def search_field(label, name)
    opts = {
      class: "form-control",
      data: {action: "blur->blank-field#blur dynamic-form#change"}
    }

    if params[name].blank?
      opts[:class] += " form-control-blank"
    end

    text_field_tag(name, params[name], opts) + label_tag(name, label)
  end

  def search_sort_button(label, value)
    search_button(label, "sort", value)
  end

  def search_query_field(label)
    search_field(label, "q")
  end

  def search_per_page_options
    {
      "10": "",
      "20": "20",
      "50": "50",
      all: "all"
    }
  end

  def search_per_page_key
    search_per_page_options.key(params[:per]) || "10"
  end

  def search_per_page_button(label, value)
    search_button(label, "per", value)
  end

  def search_filter_button(label, value)
    search_button(label, "filter", value)
  end
end
