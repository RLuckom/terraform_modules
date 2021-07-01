const _ = require('lodash'); 
const {parseResultsAccessSchema, athenaRequestsQuery} = require('./helpers/parse_cloudfront_logs')

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
                    arg: { value: metricConfigs }
                    func: athenaRequestsQuery,
                  }
                },
                QueryExecutionContext: {
                  value: _.map(metricConfigs, ({athena_catalog, glue_db}) => ({
                    Catalog: athena_catalog,
                    Database: glue_db,
                  })
                },
                ResultConfiguration: {
                  all: {
                    OutputLocation: { value: _.map(metricConfigs, (config) => config.result_location }
                  }
                }
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
          params: {
            accessSchema: { value: 'dataSources.AWS.athena.getQueryExecution' },
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryExecutionId: { ref: 'quesry.results.records'} 
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
        partitionResults: {
          formatter: (args) => {
            console.log(args)
            return args
          },
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.athena.getQueryResults'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryExecutionId: { ref: 'query.results.records'} 
              },
            },
          }
        },
      },
    },
  }
}
