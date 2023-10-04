# various helpers for searching via query params on index pages
module SearchHelper
  def search_sort_button(label, value)
    opts = {
      type: "button",
      class: "dropdown-item text-decoration-none",
      name: "sort",
      data: {action: "dynamic-form#change"},
      value: value
    }

    if params[:sort] == value || (params[:sort].blank? && value.blank?)
      opts[:class] += " active"
      opts[:aria] = {current: "page"}
    end

    button_tag(label, opts)
  end

  def search_query_field(label)
    opts = {
      class: "form-control",
      data: {action: "blur->blank-field#blur dynamic-form#change"}
    }

    if params[:q].blank?
      opts[:class] += " form-control-blank"
    end

    text_field_tag("q", params[:q], opts) + label_tag("q", label)
  end
end
