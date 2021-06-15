const _ = require('lodash'); 
const {parseReportAccessSchema} = require('./parse_report_utils')

module.exports = {
  stages: {
    file: {
      index: 0,
      dependencies: {
        file: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            explorandaParams: {
              Bucket: {ref: 'stage.bucket'},
              Key: {ref: 'stage.imageKey'},
            }
          }
        }
      }
    },
    parseReport: {
      index: 1,
      dependencies: {
        parsed: {
          action: 'exploranda',
          params: {
            accessSchema: { value: parseReportAccessSchema },
            params: {
              explorandaParams: {
                buf: { ref: 'file.results.file[0].Body'},
              }
            }
          },
        },
      },
    },
    saveSummary: {
      index: 2,
      dependencies: {
        save: {
          action: 'exploranda',
          params: {
            accessSchema: { value: 'dataSources.AWS.s3.putObject' },
            explorandaParams: {
              Bucket: { value: '${destination.bucket}' },
              Body: { 
                helper: ({parsed}) => JSON.stringify(parsed),
                params: {
                  parsed: {ref: 'parseReport.results.parsed[0]' },
                },
              },
              ContentType: { value: 'application/json'},
              Key: { value: '${trimsuffix(destination.prefix, "/")}/report_summary.json'}
            }
          }
        }
      }
    }
  }
}
