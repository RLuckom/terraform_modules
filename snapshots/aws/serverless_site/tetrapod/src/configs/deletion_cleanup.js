const _ = require('lodash')
const { siteDescriptionDependency } = require('./helpers/idUtils')

module.exports = {
  stages: {
    siteDescription: {
      index: 0,
      transformers: {
        key: {
          or: [
            {ref: 'event.Records[0].s3.object.decodedKey'},
            {ref: 'event.item.memberUri'},
            {ref: 'event.item.uri'},
          ]
        },
      },
      dependencies: {
        siteDescription: siteDescriptionDependency('${domain_name}', '${site_description_path}')
      },
    },
    item: {
      index: 1,
      transformers: {
        metadata: {
          helper: 'idUtils.identifyItem',
          params: {
            siteDescription: {ref: 'siteDescription.results.siteDescription'}, 
            resourcePath: {ref: 'siteDescription.vars.key'},
          },
        },
      },
    },
    meta: {
      condition: {
        helper: 'transform',
        params: {
          arg: { ref: 'item.vars.metadata.type' },
          func: (t) => t !== 'trail'
        }
      },
      index: 4,
      transformers: {
        trailNames: {value: []},
      },
      dependencies: {
        trails: {
          action: 'DD',
          params: {
            FunctionName: {value: '${dependency_update_function}'},
            InvocationType: { value: 'RequestResponse' },
            event: { 
              all: {
                item: {ref: 'item.vars.metadata'},
                trailNames: { ref: 'stage.trailNames'}
              }
            }
          }
        }
      }
    },
    deleteItemFromWebsiteBucket: {
      index: 5,
      dependencies: {
        uploadHtml: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: '${website_bucket}',
                Key: { ref: 'item.vars.metadata.formatUrls.html.path' },
              }
            }
          },
        }
      },
    },
  },
}
