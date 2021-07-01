const { Readable } = require('stream');

const csv = require('csv-parser')
const _ = require('lodash')

function toSecs(s) {
  return _.parseInt(s.slice(0, 2)) * 3600 + _.parseInt(s.slice(3, 5)) * 60 + _.parseInt(s.slice(6, 8))
}

const parseResultsAccessSchema = {
  dataSource: 'GENERIC_FUNCTION',
  namespaceDetails: {
    name: 'RequestRecordParser',
    paramDriven: true,
    parallel: true,
  },
  name: 'ParseResults',
  requiredParams: {
    buf: {},
  },
  params: {
    apiConfig: {
      apiObject: parseResults,
    },
  }
};

function parseResults({buf}, callback) {
  const metrics = {
    ips: {}
  }
  const ips = metrics.ips
  const requestRecords = []

  Readable.from(buf)
  .pipe(csv())
  .on('data', (data) => {
    if (!ips[data.requestIp]) {
      ips[data.requestIp] = {
        hits: 0,
        atsl: 0,
        tsls: []
      }
    }
    const oldLast = ips[data.requestIp].last
    ips[data.requestIp].last = toSecs(data.time)
    const tsl = oldLast - ips[data.requestIp].last
    ips[data.requestIp].tsls.push(tsl)
    ips[data.requestIp].atsl = ips[data.requestIp].hits ? (ips[data.requestIp].atsl * ips[data.requestIp].hits + tsl) / ips[data.requestIp].hits + 1 : null
    ips[data.requestIp].hits++
      requestRecords.push(data)
  }).on('end', () => {
    _.each(metrics.ips, (p) => {
      if (p.atsl) {
        p.full = 300 * p.hits 
        p.score = p.hits * p.atsl / p.full
        p.dist = _.countBy(p.tsls, (tsl) => {
          if (tsl < 2) {
            return -1
          } else if (tsl < 3) {
            return 0
          } else if (tsl < 5) {
            return 1
          } else if (tsl < 20) {
            return 2
          } else if (tsl < 60) {
            return 3
          } else if (tsl < 600) {
            return 4
          }
          return 5
        })
        if ((p.dist["-1"] > 2) || (p.dist['-1'] + p.dist['0'] + p.dist['1']) > 4 || p.score < 0.25) {
          p.flag = true
        }
      }
    })
    const hits = _.reduce(requestRecords, (acc, v) => {
      if (!ips[v.requestIp].flag && v.status === '200') {
        acc[v.uri] = (acc[v.uri] || 0) + 1
      }
      return acc
    }, {})
    callback(null, {hits, metrics})
  })
}

function athenaRequestsQuery(args) {
  const now = new Date()
  return _.map(args, ({glue_db, glue_table}) => {
    return `SELECT time, location, requestIp, uri, referrer, status, useragent
    FROM "${glue_db}"."${glue_table}"
    WHERE year = '${now.getUTCFullYear()}'
    AND month = '${now.getUTCMonth()}'
    AND day = '${now.getUTCDate()}'
    AND hour = '${now.getUTCHours()}'
    AND uri LIKE '/posts/%'
    AND uri NOT LIKE '%favicon.ico%'
    AND method = 'GET'
    AND useragent != '-'
    AND useragent NOT LIKE '%facebookexternalhit%'
    AND useragent NOT LIKE '%InfoTigerBot%'
    AND useragent NOT LIKE '%coccocbot%'
    AND useragent NOT LIKE '%similartech%'
    AND useragent NOT LIKE '%neevabot%'
    AND useragent NOT LIKE '%exabot%'
    AND useragent NOT LIKE '%Search%Robot%'
    AND useragent NOT LIKE '%crusty%'
    AND useragent NOT LIKE '%Crawler%'
    AND useragent NOT LIKE '%crawler4j%'
    AND useragent NOT LIKE '%eventures%'
    AND useragent NOT LIKE '%DotBot%'
    AND useragent NOT LIKE '%PickyBot%'
    AND useragent NOT LIKE '%semanticscholar%'
    AND useragent NOT LIKE '%gocolly%'
    AND useragent NOT LIKE '%Applebot%'
    AND useragent NOT LIKE '%cis455crawler%'
    AND useragent NOT LIKE '%MauiBot%'
    AND useragent NOT LIKE '%Amazonbot%'
    AND useragent NOT LIKE '%Weavr%'
    AND useragent NOT LIKE '%Faraday%'
    AND useragent NOT LIKE '%GetUrl%'
    AND useragent NOT LIKE '%jambot.com%'
    AND useragent NOT LIKE '%AndersPinkBot%'
    AND useragent NOT LIKE '%Bytespider%'
    AND useragent NOT LIKE '%LivelapBot%'
    AND useragent NOT LIKE '%Mediatoolkitbot%'
    AND useragent NOT LIKE '%yacybot%'
    AND useragent NOT LIKE '%SerendeputyBot%'
    AND useragent NOT LIKE '%MTRobot%'
    AND useragent NOT LIKE '%DarcyRipper%'
    AND useragent NOT LIKE '%node-fetch%'
    AND useragent NOT LIKE '%ELinks%'
    AND useragent NOT LIKE '%mojeek%'
    AND useragent NOT LIKE '%okhttp%'
    AND useragent NOT LIKE '%Needle%'
    AND useragent NOT LIKE '%Rustbot%'
    AND useragent NOT LIKE '%Semanticbot%'
    AND useragent NOT LIKE '%HubPages%'
    AND useragent NOT LIKE '%Trendsmap%'
    AND useragent NOT LIKE '%crawler@alexa.com%'
    AND useragent NOT LIKE '%techinfo@ubermetrics-technologies.com%'
    AND useragent NOT LIKE '%Anthill%'
    AND useragent NOT LIKE '%linkfluence%'
    AND useragent NOT LIKE '%panscient%'
    AND useragent NOT LIKE '%ahrefs.com%'
    AND useragent NOT LIKE '%netEstate%'
    AND useragent NOT LIKE '%Twitterbot%'
    AND useragent NOT LIKE '%ltx71.com%'
    AND useragent NOT LIKE '%HTTrack%'
    AND useragent NOT LIKE '%NotionEmbedder%'
    AND useragent NOT LIKE '%archive-it%'
    AND useragent NOT LIKE '%Cyotek%'
    AND useragent NOT LIKE '%Synapse%'
    AND useragent NOT LIKE '%MegaIndex%'
    AND useragent NOT LIKE '%Nutch%'
    AND useragent NOT LIKE '%Googlebot%'
    AND useragent NOT LIKE '%bingbot%'
    AND useragent NOT LIKE '%petalbot%'
    AND useragent NOT LIKE '%LightspeedSystemsCrawler%'
    AND useragent NOT LIKE '%CCBot%'
    AND useragent NOT LIKE '%SemrushBot%'
    AND useragent NOT LIKE '%SeznamBot%'
    AND useragent NOT LIKE '%Barkrowler%'
    AND useragent NOT LIKE '%Adsbot%'
    AND useragent NOT LIKE '%MJ12bot%'
    AND useragent NOT LIKE '%Slackbot%'
    AND useragent NOT LIKE '%LinkedInBot%'
    AND useragent NOT LIKE '%yandex%'
    AND useragent NOT LIKE '%webmeup%'
    AND useragent NOT LIKE '%RU_Bot%'
    AND useragent NOT LIKE '%Sogou%'
    AND useragent NOT LIKE '%paper.li%'
    AND useragent NOT LIKE '%PageThing%'
    AND useragent NOT LIKE '%DuckDuckGo-Favicons-Bot%'
    AND useragent NOT LIKE '%komodia%'
    AND useragent NOT LIKE '%discordapp%'
    AND useragent NOT LIKE '%Dataprovider.com%'`
  })
}

module.exports = {
  parseResults,
  parseResultsAccessSchema,
  athenaRequestsQuery,
}
