const _ = require('lodash')
const { parseKey, athenaPartitionQuery, createDatedS3Key} = require('./helpers/athenaHelpers')


// e.g { log_delivery_prefix: log_storage_destination}
const logDestinations = ${log_destinations_map}
const athenaDestinations = ${athena_destinations_map}

module.exports = {
  stages: {
    addPartitions: {
      index: 0,
      transformers: {
        storageConfig: {
          helper: 'transform',
          params: {
            arg: {
              all: {
                logDestinationsMap: {value: ${log_destinations_map}},
                athenaResultLocationsMap: {value: ${athena_destinations_map}},
                glueDbMap: {value: ${glue_db_map}},
                glueTableMap: {value: ${glue_table_map}},
                objectKey: {ref: 'event.Records[0].s3.object.key'},
              }
            },
            func: parseKey
          }
        }
      },
      dependencies: {
        partitions: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.athena.startQueryExecution'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryString: {
                  helper: 'transform',
                  params: {
                    arg: { ref: 'stage.storageConfig' },
                    func: athenaPartitionQuery,
                  }
                },
                QueryExecutionContext: {
                  all: {
                    Catalog: {value: '${athena_catalog}'},
                    Database: {ref: 'stage.storageConfig.glueDb'},
                  }
                },
                ResultConfiguration: {
                  all: {
                    OutputLocation: { ref: 'stage.storageConfig.athenaResultLocation' }
                  }
                }
              },
            },
          },
        },
      },
    },
    waitForPartitions: {
      index: 1,
      dependencies: {
        completion: {
          action: 'exploranda',
          params: {
            accessSchema: { value: 'dataSources.AWS.athena.getQueryExecution' },
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryExecutionId: { ref: 'addPartitions.results.partitions'} 
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
    partitionResults: {
      index: 2,
      dependencies: {
        partitionResults: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.athena.getQueryResults'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${athena_region}'}},
                QueryExecutionId: { ref: 'addPartitions.results.partitions'} 
              },
            },
          }
        },
      },
    },
    copy: {
      index: 3,
      transformers: {
        copySource: {
          helper: 'transform',
          params: {
            arg: {
              all: {
                bucket: {ref: 'event.Records[0].s3.bucket.name'},
                key: {ref: 'event.Records[0].s3.object.key'},
              }
            },
            func: ({bucket, key}) => '/' + bucket + '/' + key
          },
        }
      }, 
      dependencies: {
        copy: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.copyObject'},
            params: {
              explorandaParams: {
                Bucket: '${partition_bucket}',
                CopySource: {ref: 'stage.copySource'},
                Key: { ref: 'addPartitions.vars.storageConfig.datedArchiveKey'} 
              }
            }
          },
        }
      },
    },
    delete: {
      index: 4,
      dependencies: {
        delete: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'event.Records[0].s3.bucket.name'},
                Key: {ref: 'event.Records[0].s3.object.key'},
              },
            }
          }
        },
      }
    }
  }
}
