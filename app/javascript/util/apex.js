import ApexCharts from "apexcharts"

export const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    zoom: { enabled: false },
    animations: {
      speed: 500,
      animateGradually: {
        enabled: true,
        delay: 15,
      },
      dynamicAnimation: {
        enabled: true,
        speed: 500,
      },
    },
    toolbar: {
      show: false,
    },
  },
  stroke: {
    curve: "smooth",
    width: 2,
  },
  legend: {
    show: false,
  },
}

export const DATETIME_OPTIONS = {
  xaxis: {
    type: "datetime",
    labels: {
      datetimeFormatter: {
        year: "yyyy",
        month: "MMM d",
        day: "MMM d",
        hour: "MMM d, h:mmtt",
      },
    },
  },
  tooltip: {
    enabled: true,
    shared: true,
    hideEmptySeries: false,
    intersect: false,
    x: {
      format: "MMM d, h:mmtt",
    },
  },
  dataLabels: {
    enabled: false,
  },
  fill: {
    type: "gradient",
    gradient: {
      shade: "light",
      type: "vertical",
      opacityFrom: 0.9,
      opacityTo: 0.3,
      stops: [0, 100],
    },
  },
}

export const BAR_CHART = {
  chart: {
    type: "bar",
    stacked: false,
  },
}

export const LINE_CHART = {
  chart: {
    type: "line",
    stacked: false,
  },
}

export const BAR_DEFAULTS = {
  plotOptions: {
    bar: {
      horizontal: true,
    },
  },
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

export function updateOptions(id, options) {
  ApexCharts.exec(id, "updateOptions", options)
}

export function updateSeries(id, series) {
  ApexCharts.exec(id, "updateSeries", series)
}
