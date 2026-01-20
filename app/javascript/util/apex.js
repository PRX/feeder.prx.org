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
    intersect: true,
    // followCursor: true,
  },
  dataLabels: {
    enabled: false,
  },
}

const NUMERIC_OPTIONS = {
  xaxis: {
    type: "numeric",
    decimalsInFloat: 0,
    tickPlacement: "on",
  },
  tooltip: {
    enabled: true,
    shared: true,
    hideEmptySeries: true,
    intersect: false,
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
  },
}

export const AREA_TYPE = {
  chart: {
    type: "area",
    stacked: false,
  },
  options: {
    fill: {
      type: "solid",
      opacity: 0.8,
    },
    stroke: {
      width: 1,
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
  addYaxisTitle(options.yaxis, title)
  return new ApexCharts(target, options)
}

export function dynamicBarAndAreaType(dateRange) {
  if (dateRange.length <= 200) {
    return BAR_TYPE
  } else {
    return AREA_TYPE
  }
}

export function buildNumericChart(id, series, target, type, title = "") {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, NUMERIC_OPTIONS, type.options)
  const xdataLength = series[0].data.length - 1
  Object.assign(options.xaxis, { tickAmount: xdataLength })
  Object.assign(options.chart, { id: id }, type.chart)
  addXaxisTitle(options.xaxis, title)
  return new ApexCharts(target, options)
}

export function buildDownloadsSeries(data, dateRange) {
  if (Array.isArray(data)) {
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
        data: alignDownloadsOnDateRange(episodeRollup.rollups, dateRange),
        color: color,
        zIndex: zIndex,
      }
    })
  } else {
    return [
      {
        name: data.label,
        data: alignDownloadsOnDateRange(data.rollups, dateRange),
        color: lightBlue,
      },
    ]
  }
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

function addYaxisTitle(yaxis, title = "") {
  Object.assign(yaxis, { title: { text: title } })
}

function addXaxisTitle(xaxis, title = "") {
  Object.assign(xaxis, { title: { text: title } })
}

export function destroyChart(chartId) {
  ApexCharts.exec(chartId, "destroy")
}
