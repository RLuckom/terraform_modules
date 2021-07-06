const _ = require('lodash'); 
const {update, batchExecuteStatement, makeDynamoUpdates, parseResultsAccessSchema, athenaRequestsQuery} = require('./helpers/parse_cloudfront_logs')

const metricConfigs = ${site_metric_configs}

module.exports = {
  stages: {
    query: {
      index: 0,
      dependencies: {
        records: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.athena.startQueryExecution'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryString: {
                  helper: 'transform',
                  params: {
                    arg: { value: metricConfigs },
                    func: athenaRequestsQuery,
                  }
                },
                QueryExecutionContext: {
                  value: _.map(metricConfigs, ({athena_catalog, glue_db}) => ({
                    Catalog: athena_catalog,
                    Database: glue_db,
                  }))
                },
                ResultConfiguration: {
                  value: _.map(metricConfigs, (config) => ({
                    OutputLocation: config.result_location
                  }))
                },
              },
            },
          },
        },
      }
    },
    waitForResults: {
      index: 1,
      dependencies: {
        completion: {
          action: 'exploranda',
          formatter: ({completion}) => {
            const ret = _.map(completion, (c) => {
              const loc = _.get(c, 'ResultConfiguration.OutputLocation')
              return {
                key: loc.split('/').slice(3).join('/'),
                bucket: loc.split('/')[2]
              }
            })
            const arrays = {
              buckets: _.map(ret, 'bucket'),
              keys: _.map(ret, 'key')
            }
            console.log(arrays)
            return arrays
          },
          params: {
            accessSchema: { value: 'dataSources.AWS.athena.getQueryExecution' },
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryExecutionId: { ref: 'query.results.records'} 
              },
            },
            behaviors: {
              value: {
                retryParams: {
                  times: 60,
                  interval: 10000,
                  errorFilter: (err) => {
                    return (err === 'QUEUED' || err === 'RUNNING')
                  }
                },
                detectErrors: (err, res) => {
                  const status = _.get(res, 'QueryExecution.Status.State')
                  if (status !== 'SUCCEEDED') {
                    if (process.env.EXPLORANDA_DEBUG) {
                      console.log(err)
                    }
                    return status
                  }
                }
              }
            },
          }
        },
      },
    },
    getResults: {
      index: 2,
      dependencies: {
        results: {
          formatter: ({results}) => {
            return _.map(results, 'Body')
          },
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            explorandaParams: {
              Bucket: { ref: 'waitForResults.results.completion.buckets'}, 
              Key: { ref: 'waitForResults.results.completion.keys'} 
            }
          }
        }
      },
    },
    parseResults: {
      index: 3,
      dependencies: {
        results: {
          formatter: ({results}) => {
            console.log(results[0].hits)
            return results
          },
          action: 'exploranda',
          params: {
            accessSchema: {value: parseResultsAccessSchema},
            explorandaParams: {
              buf: { ref: 'getResults.results.results'}, 
            }
          }
        }
      },
    },
    updateDynamo: {
      index: 4,
      transformers: {
        dynamoUpdates: {
          helper: ({parseResults}) => {
            return _.flatten(_.map(parseResults, ({hits}, idx) => {
              return makeDynamoUpdates(hits, metricConfigs[idx].dynamo_table_name)
            }))
          },
          params: {
            parseResults: { ref: 'parseResults.results.results' },
          }
        }
      },
      dependencies: {
        dynamoUpdates: {
          action: 'exploranda',
          condition: { ref: 'stage.dynamoUpdates.length' },
          params: {
            accessSchema: {value: batchExecuteStatement },
            params: {
              explorandaParams: {
                apiConfig: { value: {region: '${dynamo_region}' }},
                Statements: { ref: 'stage.dynamoUpdates' },
              }
            }
          }
        },
      },
    },
  }
}
