module ApplicationHelper
  def toast_class(level)
    classes = {
      "notice" => "toast bg-success",
      "success" => "toast bg-success",
      "error" => "toast bg-danger",
      "alert" => "toast bg-danger"
    }
    classes[level]
  end

  def tab_link_to(*args, &block)
    name = block ? capture(&block) : args.shift
    options = args.shift || {}
    html_options = args.shift || {}

    # add our tab classes
    if html_options[:class].present?
      html_options[:class] += " prx-tab | nav-link"
    else
      html_options[:class] = "prx-tab | nav-link"
    end

    # add aria current page
    if is_active_link?(options)
      html_options[:aria] ||= {}
      html_options[:aria][:current] = "page"
    end

    # call through
    active_link_to(name, options, html_options)
  end

  def blank_dash(*args, &block)
    if args.any?(&:blank?)
      "&mdash;".html_safe
    elsif block
      capture(&block)
    else
      args.last
    end
  end

  def field_help_text(text)
    tag.a class: "input-group-text prx-input-group-text", tabindex: 0, role: "button", data: {popover_target: "trigger", bs_trigger: "focus", bs_content: text} do
      tag.span "help", class: "material-icons"
    end
  end

  def help_text(text)
    tag.a class: "prx-btn-help", tabindex: 0, role: "button", data: {popover_target: "trigger", bs_trigger: "focus", bs_content: text} do
      tag.span "help", class: "material-icons"
    end
  end

  def field_link(href)
    link_to href, class: "input-group-text prx-input-group-text", target: :_blank do
      tag.span "link", class: "material-icons"
    end
  end
end
