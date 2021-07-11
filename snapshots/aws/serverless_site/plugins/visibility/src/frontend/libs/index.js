function siteContainerId(name) {
  return `site-metric-container-${name}`
}

window.RENDER_CONFIG = {
  init: ({costReportSummary}, gopher) => {
    console.log(costReportSummary)
    const mainSection = document.querySelector('main')
    _.each(domNode([
      {
        tagName: 'div',
        classNames: ['metric-container'],
        children: [
          {
            tagName: 'div',
            classNames: ['metric-container-title'],
            children: [I18N_CONFIG.total_cost],
          },
          {
            tagName: 'div',
            classNames: 'metric-scalar-value',
            children: [`$${_.round(costReportSummary.overall.blendedCost, 2)}`]
          }
        ]
      },
    ]), (n) => mainSection.appendChild(n))
  },
  smallScreenFormatters: {
    toggleTray: () => {
      function toggleTray (evt) {
        evt.target.closest('.post-list-entry').classList.toggle('open')
      }
      function revert() {
        _.map(
          document.querySelectorAll('.post-list-entry'),
          (el) => {
            el.removeEventListener('click', toggleTray)
          }
        )
      }
      _.map(
        document.querySelectorAll('.post-list-entry'),
        (el) => {
          el.addEventListener('click', toggleTray)
        }
      )
      return revert
    }
  },
  params: {
    costReportSummary: {
      source: 'costReportSummary',
      formatter: ({costReportSummary}) => {
        return costReportSummary
      }
    },
  },
  onAPIError: (e, r, cb) => {
    console.error(e)
    if (_.isString(_.get(e, 'message')) && e.message.indexOf('401') !== -1) {
      location.reload()
    }
    return cb(e, r)
  },
}
