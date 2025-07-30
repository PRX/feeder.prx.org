import ApexCharts from "apexcharts"

export const DEFAULT_OPTIONS = {
  chart: {
    width: "100%",
    zoom: { enabled: false },
    animations: {
      speed: 500,
      animateGradually: {
        delay: 10,
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

export function setDateTimeFormatter(interval) {
  if (interval === "MONTH") {
    return {
      month: "MMMM yyyy",
      day: "MMM d",
    }
  } else if (interval === "HOUR") {
    return {
      day: "dddd, h:mmtt",
      hour: "d/M/yy, h:mmtt",
    }
  } else {
    return {
      month: "MMM d",
      day: "d/M/yy",
      hour: "MMM d, h:mmtt",
    }
  }
}

export function apexToggleSeries(chartId, series) {
  ApexCharts.exec(chartId, "toggleSeries", series)
}
