const { Readable } = require('stream');
const zlib = require('zlib');

const csv = require('csv-parser')
const _ = require('lodash')

const parseReportAccessSchema = {
  dataSource: 'GENERIC_FUNCTION',
  namespaceDetails: {
    name: 'BillingReportParser',
    paramDriven: true,
    parallel: true,
  },
  name: 'ParseReport',
  requiredParams: {
    buf: {},
  },
  params: {
    apiConfig: {
      apiObject: parseReport,
    },
  }
};

function parseReport({buf}, callback) {
  const results = {
    overall: {
      blendedCost: 0
    },
    products: {}
  };
  const reportReadStream = Readable.from(buf).pipe(zlib.createGunzip())
  .pipe(csv())
  .on('data', (data) => {
    const lineCost = _.toNumber(_.get(data, 'lineItem/BlendedCost')) || 0
    const usageType = _.get(data, 'lineItem/UsageType')
    const product = _.get(data, 'product/ProductName')
    const resourceId = _.get(data, 'lineItem/ResourceId')
    const operation = _.get(data, "lineItem/Operation")
    const usageAmount = _.toNumber(_.get(data, "lineItem/UsageAmount"))
    if (product && !results.products[product]) {
      results.products[product] = {
        blendedCost: 0,
        usageTypes: {},
        resources: {}
      }
    }
    if (usageType && !results.products[product].usageTypes[usageType]) {
      results.products[product].usageTypes[usageType] = {
        blendedCost: 0,
        resources: {}
      }
    }
    if (resourceId && !results.products[product].resources[resourceId]) {
      results.products[product].resources[resourceId] = {
        blendedCost: 0,
        usageTypes: {},
      }
    }
    if (resourceId && usageType && !results.products[product].usageTypes[usageType].resources[resourceId]) {
      results.products[product].usageTypes[usageType].resources[resourceId] = {
        blendedCost: 0,
        resources: {},
      }
    }
    if (resourceId && usageType && !results.products[product].resources[resourceId].usageTypes[usageType]) {
      results.products[product].resources[resourceId].usageTypes[usageType] = {
        blendedCost: 0,
        operations: {},
      }
    }
    if (resourceId && usageType && operation && !results.products[product].resources[resourceId].usageTypes[usageType].operations[operation]) {
      results.products[product].resources[resourceId].usageTypes[usageType].operations[operation] = {
        blendedCost: 0,
        usageAmount: 0,
      }
    }
    if (resourceId && usageType) {
      results.products[product].resources[resourceId].usageTypes[usageType].blendedCost += lineCost
      results.products[product].usageTypes[usageType].resources[resourceId].blendedCost += lineCost
    }
    if (resourceId && operation && usageType) {
      results.products[product].resources[resourceId].usageTypes[usageType].operations[operation].blendedCost += lineCost
      results.products[product].resources[resourceId].usageTypes[usageType].operations[operation].usageAmount += usageAmount
    }
    if (usageType) {
      results.products[product].usageTypes[usageType].blendedCost += lineCost
    }
    if (resourceId) {
      results.products[product].resources[resourceId].blendedCost += lineCost
    }
    results.overall.blendedCost += lineCost
    results.products[product].blendedCost += lineCost
  })
  .on('error', (e) => {
    callback(e)
  })
  .on('end', () => {
    callback(null, results)
  });
}

module.exports = {parseReportAccessSchema}
