module ApplicationHelper
  def tab_link_to(*args, &block)
    name = block ? capture(&block) : args.shift
    options = args.shift || {}
    html_options = args.shift || {}

    # add our tab classes
    if html_options[:class].present?
      html_options[:class] += " list-group-item"
    else
      html_options[:class] = "list-group-item"
    end

    # add aria current page
    if is_active_link?(options)
      html_options[:aria] ||= {}
      html_options[:aria][:current] = "page"
    end

    # call through
    active_link_to(name, options, html_options)
  end
end
