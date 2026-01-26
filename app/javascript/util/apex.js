import ApexCharts from "apexcharts"

const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    height: "100%",
    zoom: { enabled: false },
    animations: {
      enabled: false,
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
  yaxis: {
    show: true,
  },
  tooltip: {
    enabled: true,
    shared: false,
    hideEmptySeries: true,
    intersect: false,
    followCursor: true,
    marker: {
      show: true,
    },
  },
  dataLabels: {
    enabled: false,
  },
}

const lightBlue = "#aafff5"
const lightPink = "#e7d4ff"
const midBlue = "#c9e9fa"
const orange = "#ff9601"

export const BAR_TYPE = {
  chart: {
    type: "bar",
    stacked: false,
    animations: {
      enabled: false,
    },
    sparkline: {
      enabled: false,
    },
  },
  options: {
    fill: {
      colors: [lightBlue],
      type: "gradient",
      opacity: 1,
      gradient: {
        type: "vertical",
        shade: "light",
        inverseColors: false,
        gradientToColors: [lightPink],
      },
    },
    tooltip: {
      shared: true,
      intersect: false,
    },
    states: {
      hover: {
        filter: {
          type: "none",
        },
      },
    },
  },
}

export const LINE_TYPE = {
  chart: {
    type: "line",
    stacked: false,
    animations: {
      enabled: false,
    },
    sparkline: {
      enabled: false,
    },
  },
  options: {
    stroke: {
      curve: "smooth",
      width: 3,
    },
    markers: {
      showNullDataPoints: false,
    },
    tooltip: {
      onDatasetHover: {
        highlightDataSeries: true,
      },
      shared: true,
      followCursor: true,
    },
  },
}

export const SPARKLINE_TYPE = {
  chart: {
    height: "100%",
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
    },
    type: "area",
    stacked: false,
  },
  options: {
    xaxis: {
      type: "datetime",
    },
    tooltip: {
      enabled: false,
    },
    fill: {
      colors: [lightBlue],
      type: "gradient",
      gradient: {
        type: "vertical",
        shade: "light",
        gradientToColors: [lightPink],
        inverseColors: false,
        opacityFrom: 0.9,
        opacityTo: 0.9,
      },
    },
    stroke: {
      width: 1,
      colors: ["#00000000"],
    },
  },
}

export const SPARKBAR_TYPE = {
  chart: {
    height: "100%",
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
    },
    type: "bar",
    stacked: false,
  },
  options: {
    xaxis: {
      type: "category",
    },
    tooltip: {
      enabled: false,
    },
    fill: {
      colors: [lightBlue],
      type: "gradient",
      gradient: {
        type: "horizontal",
        shade: "light",
        gradientToColors: [lightPink],
        inverseColors: true,
        opacityFrom: 0.9,
        opacityTo: 0.9,
      },
    },
    stroke: {
      width: 1,
      colors: ["#00000000"],
    },
    plotOptions: {
      bar: {
        horizontal: true,
        barHeight: "90%",
      },
    },
    states: {
      hover: {
        filter: {
          type: "none",
        },
      },
    },
  },
}

export function buildSparklineChart(id, series, target) {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, SPARKLINE_TYPE.options)
  Object.assign(options.chart, { id: id }, SPARKLINE_TYPE.chart)
  return new ApexCharts(target, options)
}

export function buildSparkbarChart(id, series, target) {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, SPARKBAR_TYPE.options)
  Object.assign(options.chart, { id: id }, SPARKBAR_TYPE.chart)
  return new ApexCharts(target, options)
}

export function buildDateTimeChart(id, series, target, type, dateRange = [], title = "") {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, DATETIME_OPTIONS, type.options)
  Object.assign(options.chart, { id: id }, type.chart)
  Object.assign(options.xaxis, { categories: dateRange })
  return new ApexCharts(target, options)
}

export function buildDownloadsSeries(data, dateRange) {
  return [
    {
      name: "Downloads",
      data: alignDownloadsOnDateRange(data, dateRange),
      color: lightBlue,
    },
  ]
}

export function buildMultipleEpisodeDownloadsSeries(data, dateRange) {
  return data.map((episodeRollup, i) => {
    let zIndex = 1
    if (i === 0) {
      zIndex = 2
    }
    let color = midBlue
    if (i === 0) {
      color = orange
    }
    return {
      name: episodeRollup.episode.title,
      data: episodeRollup.rollups,
      color: color,
      zIndex: zIndex,
    }
  })
}

function alignDownloadsOnDateRange(downloads, range) {
  return range.map((date) => {
    const match = downloads.filter((r) => {
      return r[0] === date
    })

    if (match[0]) {
      return {
        x: date,
        y: match[0][1],
      }
    } else {
      return {
        x: date,
        y: null,
      }
    }
  })
}

export function destroyChart(chartId) {
  ApexCharts.exec(chartId, "destroy")
}
