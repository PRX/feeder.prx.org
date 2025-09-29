class Megaphone::PagedCollection
  attr_accessor :api, :model, :items, :per_page, :page, :total, :links

  def initialize(api, model, result)
    @api = api
    @model = model
    set_result(result)
  end

  def set_result(result)
    @items = (result[:items] || []).map { |i| model.new(i) }

    paging = result[:pagination] || {}
    @per_page = paging[:per_page]
    @page = paging[:page]
    @total = paging[:total]
    @links = paging[:link]
  end

  def count
    items.length
  end

  def next_page
    links[:next]
  end

  def next?
    next_page.present?
  end

  def all_items
    items_all = items
    while next?
      result = api.get_base(next_page)
      set_result(result)
      items_all += items
    end
    items_all
  end
end
