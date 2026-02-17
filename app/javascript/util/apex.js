import ApexCharts from "apexcharts"

const lightBlue = "#aafff5"
const lightPink = "#e7d4ff"
const orange = "#ff9601"
const episodeFromColors = [orange].concat(Array(10).fill(lightBlue))
const episodeToColors = [orange].concat(Array(10).fill(lightPink))

const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    height: "100%",
    zoom: { enabled: false },
    animations: {
      enabled: true,
    },
    toolbar: {
      show: false,
    },
  },
  legend: {
    show: false,
  },
  fill: {
    opacity: 1,
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
    followCursor: true,
    marker: {
      show: true,
    },
    x: {
      format: "MMM d",
    },
  },
  states: {
    hover: {
      filter: {
        type: "none",
      },
    },
  },
  theme: {
    mode: "light",
  },
}

const BAR_OPTIONS = {
  chart: {
    type: "bar",
  },
  fill: {
    gradient: {
      type: "vertical",
      shade: "light",
      inverseColors: false,
      gradientToColors: [lightPink],
    },
  },
  yaxis: {
    show: true,
  },
  dataLabels: {
    enabled: false,
  },
}

const EPISODES_OPTIONS = {
  chart: {
    type: "line",
    animations: {
      enabled: false,
    },
  },
  xaxis: {
    tooltip: {
      enabled: false,
    },
  },
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
  },
  fill: {
    colors: episodeFromColors,
    gradient: {
      type: "vertical",
      shade: "light",
      gradientToColors: episodeToColors,
      inverseColors: false,
    },
  },
  yaxis: {
    show: true,
  },
  dataLabels: {
    enabled: false,
  },
}

const SPARKLINE_OPTIONS = {
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
}

const SPARKBAR_OPTIONS = {
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

function typeOptions(chartType) {
  if (chartType === "sparkline") {
    return SPARKLINE_OPTIONS
  } else if (chartType === "sparkbar") {
    return SPARKBAR_OPTIONS
  } else if (chartType === "episodes") {
    return EPISODES_OPTIONS
  } else if (chartType === "bar") {
    return BAR_OPTIONS
  }
}

function buildOptions(chartType) {
  const options = JSON.parse(JSON.stringify(typeOptions(chartType)))
  const defaults = JSON.parse(JSON.stringify(DEFAULT_OPTIONS))

  for (const key in options) {
    defaults[key] = { ...defaults[key], ...options[key] }
  }

  return defaults
}

function setTheme() {
  let mode = "light"
  if (document.documentElement.dataset.bsTheme === "dark") {
    mode = "dark"
  }

  return mode
}

function setModeColors(options) {
  let mode = "light"
  if (document.documentElement.dataset.bsTheme === "dark") {
    mode = "dark"
  }

  let background, foreColor
  if (mode === "dark") {
    background = "#0000"
    foreColor = "#f6f7f8"
  } else {
    background = "#fff"
    foreColor = "#373d3f"
  }

  Object.assign(options.theme, { mode: mode })
  Object.assign(options.tooltip, { theme: mode })
  Object.assign(options.chart, { background: background, foreColor: foreColor })

  return options
}

export function buildChart(id, series, target, chartType) {
  const options = buildOptions(chartType)
  options.chart = { ...options.chart, id: id }
  options.series = series
  options.theme = { ...options.theme, mode: setTheme() }
  return new ApexCharts(target, options)
}

function buildDownloadsSeries(data) {
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
      color: lightBlue,
    },
  ]
}

function buildMultipleEpisodeDownloadsSeries(data) {
  return data.map((episodeRollup, i) => {
    let zIndex = 1
    if (i === 0) {
      zIndex = 2
    }
    let color = lightBlue
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

export function buildSeries(type, data) {
  if (type === "downloads") {
    return buildDownloadsSeries(data)
  } else if (type === "episodes") {
    return buildMultipleEpisodeDownloadsSeries(data)
  }
}

export function destroyChart(chartId) {
  ApexCharts.exec(chartId, "destroy")
}
