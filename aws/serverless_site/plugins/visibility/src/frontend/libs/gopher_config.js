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
    errors: {
      accessSchema: exploranda.dataSources.AWS.dynamodb.scan,
      params: {
        apiConfig: {value: {region: CONFIG.error_table_region}},
        TableName: {value: CONFIG.error_table_name},
      },
    },
  },
  otherDependencies: {
  },
}
