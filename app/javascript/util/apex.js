import ApexCharts from "apexcharts"

const lightBlue = "#aafff5"
const lightPink = "#e7d4ff"
const midBlue = "#c9e9fa"
const orange = "#ff9601"

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
  xaxis: {
    type: "datetime",
    labels: {
      datetimeFormatter: {
        year: "yyyy",
        month: "MMM",
        day: "MMM d",
        hour: "MMM d, h:mmtt",
      },
    },
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
  states: {
    hover: {
      filter: {
        type: "none",
      },
    },
  },
}

const DATETIME_OPTIONS = {
  xaxis: {
    type: "datetime",
    labels: {
      datetimeFormatter: {
        year: "yyyy",
        month: "MMM",
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

export const SPARKLINE_OPTIONS = {
  chart: {
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
    },
    type: "area",
  },
  tooltip: {
    enabled: false,
  },
  stroke: {
    width: 1,
    colors: ["#00000000"],
  },
  fill: {
    gradient: {
      type: "vertical",
      shade: "light",
      gradientToColors: [lightPink],
      inverseColors: false,
      opacityFrom: 0.9,
      opacityTo: 0.9,
    },
  },
}

export const SPARKBAR_OPTIONS = {
  chart: {
    sparkline: {
      enabled: true,
    },
    animations: {
      enabled: true,
    },
    type: "bar",
  },
  xaxis: {
    type: "category",
  },
  tooltip: {
    enabled: false,
  },
  fill: {
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
}

function buildOptions(series, options) {
  const defaults = Object.assign({ series: series }, DEFAULT_OPTIONS)
  for (const key in options) {
    if (Object.hasOwn(defaults, key)) {
      Object.assign(defaults[key], options[key])
    } else {
      defaults[key] = options[key]
    }
  }

  return defaults
}

export function buildChart(id, series, target, typeOptions) {
  const options = buildOptions(series, typeOptions)
  Object.assign(options.chart, { id: id })
  return new ApexCharts(target, options)
}
export function buildSparklineChart(id, series, target) {
  return buildChart(id, series, target, SPARKLINE_OPTIONS)
}

export function buildSparkbarChart(id, series, target) {
  return buildChart(id, series, target, SPARKBAR_OPTIONS)
}

export function buildDateTimeChart(id, series, target, type, dateRange = [], title = "") {
  const options = Object.assign({ series: series }, DEFAULT_OPTIONS, DATETIME_OPTIONS, type.options)
  Object.assign(options.chart, { id: id }, type.chart)
  Object.assign(options.xaxis, { categories: dateRange })
  return new ApexCharts(target, options)
}

export function buildDownloadsSeries(data) {
  const seriesData = data.map((rollup) => {
    return {
      x: rollup[0],
      y: rollup[1],
    }
  })
  return [
    {
      name: "Downloads",
      data: seriesData,
      // color: lightBlue,
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

export function destroyChart(chartId) {
  ApexCharts.exec(chartId, "destroy")
}
