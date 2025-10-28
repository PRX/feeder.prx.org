import ApexCharts from "apexcharts"

const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    height: "400px",
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

export const BAR_TYPE = {
  chart: {
    type: "bar",
    stacked: false,
  },
  options: {
    fill: {
      type: "solid",
      opacity: 0.8,
    },
  },
}

export const LINE_TYPE = {
  chart: {
    type: "line",
    stacked: false,
  },
  options: {
    stroke: {
      curve: "smooth",
      width: 2,
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

export function buildDateTimeChart(id, series, target, type, title = "") {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, DATETIME_OPTIONS, type.options)
  Object.assign(options.chart, { id: id }, type.chart)
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
        name: data.label,
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

function addYaxisTitle(yaxis, title = "") {
  Object.assign(yaxis, { title: { text: title } })
}

function addXaxisTitle(xaxis, title = "") {
  Object.assign(xaxis, { title: { text: title } })
}

export function destroyChart(chartId) {
  ApexCharts.exec(chartId, "destroy")
}
