require "active_support/concern"

module StreamResourceFilters
  extend ActiveSupport::Concern

  included do
    scope :paginate, ->(page, per) do
      if per == "all"
        page(1).per(10000)
      else
        page(page).per(per)
      end
    end
  end
end
