import ApexCharts from "apexcharts"

const MetricsChart = {
  mounted() {
    this.chart = null
    this.initChart([])

    // Listen for data updates from LiveView
    this.handleEvent("metrics-update", ({data}) => {
      this.updateChartData(data)
    })
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  initChart(data) {
    const options = {
      series: [
        {
          name: "Lookup Time (µs)",
          data: data.map(d => ({ x: d.total, y: d.lookup_us }))
        },
        {
          name: "Stats Query (ms×10)",
          data: data.map(d => ({ x: d.total, y: d.stats_ms * 10 }))
        }
      ],
      chart: {
        type: "area",
        height: 200,
        background: "transparent",
        animations: {
          enabled: true,
          easing: "easeinout",
          speed: 500,
          dynamicAnimation: {
            enabled: true,
            speed: 300
          }
        },
        toolbar: { show: false },
        zoom: { enabled: false },
        sparkline: { enabled: false }
      },
      colors: ["#22d3ee", "#a855f7"],
      stroke: {
        curve: "smooth",
        width: 2
      },
      fill: {
        type: "gradient",
        gradient: {
          shadeIntensity: 1,
          opacityFrom: 0.5,
          opacityTo: 0.1,
          stops: [0, 90, 100]
        }
      },
      dataLabels: { enabled: false },
      grid: {
        borderColor: "#334155",
        strokeDashArray: 3,
        padding: { left: 10, right: 10 }
      },
      xaxis: {
        type: "numeric",
        labels: {
          style: { colors: "#94a3b8", fontSize: "10px" },
          formatter: (val) => {
            if (val >= 1000000) return (val / 1000000).toFixed(1) + "M"
            if (val >= 1000) return Math.round(val / 1000) + "K"
            return Math.round(val)
          }
        },
        title: {
          text: "Total MRIs",
          style: { color: "#64748b", fontSize: "10px" }
        },
        axisBorder: { show: false },
        axisTicks: { show: false }
      },
      yaxis: {
        labels: {
          style: { colors: "#94a3b8", fontSize: "10px" },
          formatter: (val) => Math.round(val)
        },
        title: {
          text: "µs / ms×10",
          style: { color: "#64748b", fontSize: "10px" }
        }
      },
      legend: {
        show: true,
        position: "top",
        horizontalAlign: "right",
        fontSize: "11px",
        labels: { colors: "#94a3b8" },
        markers: { width: 8, height: 8, radius: 2 }
      },
      tooltip: {
        theme: "dark",
        shared: true,
        x: {
          formatter: (val) => `${val.toLocaleString()} MRIs`
        }
      }
    }

    this.chart = new ApexCharts(this.el, options)
    this.chart.render()
  },

  updateChartData(data) {
    if (!this.chart || !data || data.length === 0) return

    this.chart.updateSeries([
      {
        name: "Lookup Time (µs)",
        data: data.map(d => ({ x: d.total, y: d.lookup_us }))
      },
      {
        name: "Stats Query (ms×10)",
        data: data.map(d => ({ x: d.total, y: d.stats_ms * 10 }))
      }
    ], true) // true = animate
  }
}

export default MetricsChart
