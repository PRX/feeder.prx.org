import ApexCharts from "apexcharts"

const DEFAULT_OPTIONS = {
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
  legend: {
    show: false,
  },
}

const DATETIME_OPTIONS = {
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
}

const NUMERIC_OPTIONS = {
  xaxis: {
    type: "numeric",
    decimalsInFloat: 0,
  },
  tooltip: {
    enabled: true,
    shared: true,
    hideEmptySeries: false,
    intersect: false,
  },
  dataLabels: {
    enabled: false,
  },
}

export const BAR_CHART = {
  chart: {
    type: "bar",
    stacked: false,
    height: "550px",
  },
  options: {
    fill: {
      type: "gradient",
      gradient: {
        shade: "light",
        type: "vertical",
        opacityFrom: 0.9,
        opacityTo: 0.6,
        stops: [0, 100],
      },
    },
    stroke: {
      width: 1,
    },
  },
}

export const LINE_CHART = {
  chart: {
    type: "line",
    stacked: false,
    height: "550px",
  },
  options: {
    stroke: {
      curve: "smooth",
      width: 2,
    },
  },
}

export const AREA_CHART = {
  chart: {
    type: "area",
    stacked: false,
    height: "550px",
  },
  options: {
    fill: {
      type: "gradient",
      gradient: {
        shade: "light",
        type: "vertical",
        opacityFrom: 0.9,
        opacityTo: 0.6,
        stops: [0, 100],
      },
    },
    stroke: {
      width: 1,
    },
  },
}

export function buildDateTimeChart(id, series, target, type) {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, DATETIME_OPTIONS, type.options)
  Object.assign(options.chart, { id: id }, type.chart)
  return new ApexCharts(target, options)
}

export function dynamicBarAndAreaChart(dateRange) {
  if (dateRange.length <= 200) {
    return BAR_CHART
  } else {
    return AREA_CHART
  }
}

export function buildNumericChart(id, series, target, type) {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, NUMERIC_OPTIONS, type.options)
  Object.assign(options.chart, { id: id }, type.chart)
  return new ApexCharts(target, options)
}

export function buildDownloadsSeries(data, dateRange) {
  if (Array.isArray(data)) {
    return data.map((episodeRollup) => {
      return {
        name: episodeRollup.episode.title,
        data: alignDownloadsOnDateRange(episodeRollup.rollups, dateRange),
        color: episodeRollup.color,
      }
    })
  } else {
    return [
      {
        name: "All Episodes",
        data: alignDownloadsOnDateRange(data.rollups, dateRange),
        color: data.color,
      },
    ]
  }
}

function alignDownloadsOnDateRange(downloads, range) {
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

// export function setDateTimeLabel(interval) {
//   if (interval === "MONTH") {
//     return "MMMM yyyy"
//   } else if (interval === "HOUR") {
//     return "MMM d, h:mmtt"
//   } else {
//     return "MMM d"
//   }
// }
