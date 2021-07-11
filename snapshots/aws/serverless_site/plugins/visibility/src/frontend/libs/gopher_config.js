const POLL_INTERVAL = 2000
window.GOPHER_CONFIG = {
  awsDependencies: {
    costReportSummary: {
      accessSchema: exploranda.dataSources.AWS.s3.getObject,
			formatter: ([costReportSummary]) => {
				return JSON.parse(costReportSummary.Body.toString('utf8'))
			},
      params: {
        Bucket: {value: CONFIG.cost_report_summary_storage_bucket },
        Key: { value: CONFIG.cost_report_summary_storage_key},
      }
    },
  },
  otherDependencies: {
  },
}
/*
window.GOPHER_CONFIG_OLD = {
	otherDependencies: {
	},
	awsDependencies: {
		costReportSummary: {
			formatter: ([costReportSummary]) => {
				return JSON.parse(costReportSummary.Body.toString('utf8'))
			},
			accessSchema: exploranda.dataSources.AWS.s3.getObject,
			params: {
				Bucket: {value: CONFIG.cost_report_summary_storage_bucket },
				Key: { value: CONFIG.cost_report_summary_storage_key },
			}
		},
		query: {
			accessSchema: exploranda.dataSources.AWS.athena.startQueryExecution,
			params: {
				apiConfig: apiConfigSelector,
				QueryString: {
					value: athenaQuery
				},
				QueryExecutionContext: {
					value: {
						Catalog: 'AwsDataCatalog',
						Database: 'prod_rluckom_visibility_data',
					}
				},
				ResultConfiguration: {
					value: {
						OutputLocation: 's3://rluckom-visibility-data/security_scope=prod/subsystem=prod/source=athena/source=cloudfront/' 
					}
				}
			},
		},
		completion: {
			accessSchema: exploranda.dataSources.AWS.athena.getQueryExecution,
			params: {
				apiConfig: apiConfigSelector,
				QueryExecutionId: { 
					source: 'query',
					formatter: ({query}) => {
						return query[0]
					}
				} 
			},
			behaviors: {
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
						console.log(err)
						return status
					}
				}
			},
		},
		results: {
			accessSchema: exploranda.dataSources.AWS.athena.getQueryResults,
			params: {
				apiConfig: apiConfigSelector,
				QueryExecutionId: { 
					source: ['query', 'completion'],
					formatter: ({query}) => {
						return query[0]
					}
				} 
			},
		},
	},
}
*/
