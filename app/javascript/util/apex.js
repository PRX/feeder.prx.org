import ApexCharts from "apexcharts"

export const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    zoom: { enabled: false },
    animations: {
      speed: 1000,
      animateGradually: {
        delay: 50,
      },
      dynamicAnimation: {
        enabled: true,
        speed: 1000,
      },
    },
    toolbar: {
      show: false,
    },
  },
}

export const LINE_DEFAULTS = {
  stroke: {
    curve: "smooth",
    width: 2,
  },
  legend: {
    show: false,
  },
}

export const BAR_DEFAULTS = {
  plotOptions: {
    bar: {
      horizontal: true,
    },
  },
}

export function mapColors(data) {
  return data.map((d) => d.color)
}

export function alignDownloadsOnDateRange(downloads, range) {
  return range.map((date) => {
    const match = downloads.filter((r) => {
      return r.hour === date
    })

    if (match[0]) {
      return {
        x: date,
        y: match[0].count,
      }
    } else {
      return {
        x: date,
        y: 0,
      }
    }
  })
}

export function setDateTimeLabel(interval) {
  if (interval === "MONTH") {
    return "MMMM yyyy"
  } else if (interval === "HOUR") {
    return "MMM d, h:mmtt"
  } else {
    return "MMM d"
  }
}

export function apexToggleSeries(chartId, series) {
  ApexCharts.exec(chartId, "toggleSeries", series)
}
