const _ = require('lodash')
const urlTemplate = require('url-template')
const formatters = require('./formatters')

function urlToPath(url, pathReString) {
  let resourcePath = url
  const pathRe = new RegExp(pathReString)
  if (pathRe.test(resourcePath)) {
    resourcePath = pathRe.exec(resourcePath)[1]
  }
  return resourcePath
}

function identifyItem({resourcePath, siteDescription, selectionPath}) {
  if (!selectionPath) {
    selectionPath = ['relations']
  }
  resourcePath = urlToPath(resourcePath, _.get(siteDescription, 'siteDetails.pathRegex')) || resourcePath
  for (key in _.get(siteDescription, selectionPath)) {
    const reString = _.get(siteDescription, _.concat(selectionPath, [key, 'pathNameRegex']))
    if (key !== 'meta' && reString) {
      const re = new RegExp(reString)
      if (re.test(resourcePath)) {
        const name = re.exec(resourcePath)[1]
        selectionPath.push(key)
        const typeDef = _.get(siteDescription, selectionPath)
        const uriTemplateArgs = {...siteDescription.siteDetails, ...{name}}
        const formatUrls = _.reduce(_.get(typeDef, 'formats'), (a, v, k) => {
          const uriTemplateString = v.idTemplate
          if (uriTemplateString) {
            const formatUri = urlTemplate.parse(uriTemplateString).expand(uriTemplateArgs)
            a[k] = {
              uri: formatUri,
              path: urlToPath(formatUri, _.get(siteDescription, 'siteDetails.pathRegex'))
            }
          }
          return a
        }, {})
        let browserUrl = null
        const browserUrlTemplate = _.get(siteDescription, _.concat(selectionPath, ['browserUrlTemplate']))
        if (browserUrlTemplate) {
          browserUrl = urlTemplate.parse(browserUrlTemplate).expand(uriTemplateArgs)
        }
        return {
          type: key,
          typeDef,
          name,
          formatUrls,
          uri: urlTemplate.parse(_.get(siteDescription, _.concat(selectionPath, ['idTemplate']))).expand(uriTemplateArgs),
          browserUrl,
          path: resourcePath
        }
      }
    }
  }
  if (_.get(siteDescription, _.concat(selectionPath, ['meta']))) {
    selectionPath.push('meta')
    return identifyItem({resourcePath, siteDescription, selectionPath})
  }
}

function identifyUriBuilder(siteDescription) {
  return function identifyUri(uri) {
    return identifyItem({resourcePath: uri, siteDescription})
  }
}

function expandUrlTemplate({templateString, templateParams}) {
  return urlTemplate.parse(templateString).expand(templateParams)
}

function expandUrlTemplateWithNames({templateString, siteDetails, names}) {
  const template = urlTemplate.parse(templateString)
  return _.map(names, (v, k) => {
    return template.expand({...siteDetails, ...{name: v}})
  })
}

function expandUrlTemplatesWithName({templateStrings, siteDetails, name}) {
  return _.map(templateStrings, (templateString, k) => {
    const template = urlTemplate.parse(templateString)
    return template.expand({...siteDetails, ...{name: name}})
  })
}

function expandUrlTemplateWithName({templateString, siteDetails, name, type}) {
  const params = {...siteDetails, ...{name: name}}
  if (type) {
    params.type = type
  }
  return urlTemplate.parse(templateString).expand(params)
}

function accumulatorUrls({siteDetails, item}) {
  return _.reduce(item.typeDef.accumulators, (a, {idTemplate}, type) => {
    a.urls.push( expandUrlTemplateWithName({templateString: idTemplate, siteDetails, name: item.name}))
    a.types.push(type)
    return a
  }, {urls: [], types: []})
}

function siteDescriptionDependency(domainName, siteDescriptionPath) {
  return {
    action: 'exploranda',
    formatter: formatters.singleValue.unwrapHttpResponse,
    params: {
      accessSchema: {
        value: {
          dataSource: 'GENERIC_API',
          host: domainName,
          path: siteDescriptionPath,
        }
      },
    },
  }
}

module.exports = {
  siteDescriptionDependency,
  identifyItem,
  identifyUriBuilder,
  urlToPath,
  accumulatorUrls,
  expandUrlTemplateWithNames,
  expandUrlTemplatesWithName,
  expandUrlTemplateWithName,
  expandUrlTemplate,
}
