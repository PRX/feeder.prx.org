class Megaphone::PagedCollection
  attr_accessor :model, :items, :per_page, :page, :total, :links

  def initialize(model, result)
    @model = model

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
end
