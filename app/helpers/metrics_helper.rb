module MetricsHelper
  def parse_trend(trend)
    return if trend.blank?

    if trend > 0
      {
        percent: "+#{(trend * 100).round(3)}%",
        color: modified_trend_color(trend, "text-success"),
        direction: modified_trend_direction(trend, "up")
      }
    elsif trend < 0
      {
        percent: "-#{(trend * -100).round(3)}%",
        color: modified_trend_color(trend, "text-danger"),
        direction: modified_trend_direction(trend, "down")
      }
    end
  end

  def modified_trend_direction(trend, direction)
    if trend.abs > 0.05
      "trending_#{direction}"
    else
      "trending_flat"
    end
  end

  def modified_trend_color(trend, color)
    if trend.abs > 0.05
      color
    else
      "text-secondary"
    end
  end

  def uses_multiple_feeds(model)
    model.feeds.length > 1
  end

  def uses_seasons(model)
    if model.is_a?(Podcast)
      model.episodes.published.where.not(season_number: nil).length > 0
    elsif model.is_a?(Episode)
      model.season_number.present?
    end
  end
end
