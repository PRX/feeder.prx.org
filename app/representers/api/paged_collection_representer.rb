# encoding: utf-8

class Api::PagedCollectionRepresenter < Api::BaseRepresenter
  property :count
  property :total

  embeds :items,
    decorator: lambda { |*| item_decorator },
    class: lambda { |*| item_class },
    zoom: :always

  link :prev do
    href_url_helper(params.merge(page: represented.prev_page)) unless represented.first_page?
  end

  link :next do
    href_url_helper(params.merge(page: represented.next_page)) unless represented.last_page?
  end

  link :first do
    href_url_helper(params.merge(page: nil)) if represented.total_pages > 1
  end

  link :last do
    href_url_helper(params.merge(page: represented.total_pages)) if represented.total_pages > 1
  end

  def params
    represented.params
  end

  def self_url(represented)
    href_url_helper(represented.params)
  end

  def profile_url(represented)
    model_uri(:collection, represented.item_class)
  end

  # refactor to use single property, :url, that can be a method name, a string, or a lambda
  # if it is a method name, execute against self - the representer - which has local url helpers methods
  # if it is a sym/string, but self does not respond to it, then just use that string
  # if it is a lambda, execute in the context against the represented.parent (if there is one) or represented
  def href_url_helper(options={})
    if represented_url.nil?
      result = url_for(options.merge(only_path: true)) rescue nil
      if represented.parent
        result ||= polymorphic_path([:api, represented.parent, represented.item_class], options) rescue nil
      end
      result ||= polymorphic_path([:api, represented.item_class], options) rescue nil
      return result
    end

    if represented_url.respond_to?(:call)
      self.instance_exec(options, &represented_url)
    elsif self.respond_to?(represented_url)
      self.send(represented_url, options)
    else
      represented_url.to_s
    end
  end

  def represented_url
    @represented_url ||= represented.try(:url)
  end
end
