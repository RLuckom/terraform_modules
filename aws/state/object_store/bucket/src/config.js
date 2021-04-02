const _ = require('lodash')

const rules = _.sortBy(${rules}, 'priority')

function getDestinationFromHighestMatchingRule({key, tags, eventType}) {
  const tagObject = _.reduce(tags, (acc, v, k) => {
    acc[v.Key] = v.Value
    return acc
  }, {})
  const rule = _.find(rules, (rule) => {
    return (
      _.startsWith(key, rule.filter.prefix || "") &&
      _.endsWith(key, rule.filter.suffix || "") &&
      _.reduce(rule.filter.tags, (acc, v, k) => {
        return acc && tagObject[k] === v
      }, true)
    )
  })
  if (rule) {
    if (_.startsWith(eventType, "s3:ObjectCreated")) {
      return {
        copy: true,
        bucket: rule.destination.bucket === "" ? "${bucket}" : rule.destination.bucket,
        copySource: '/${bucket}/' + key,
        key: (rule.destination.prefix || "") + _.replace(key, rule.filter.prefix, "")
      }
    } else if (_.startsWith(eventType, "s3:ObjectRemoved") && rule.replicate_delete) {
      return {
        delete: true,
        bucket: rule.destination.bucket === "" ? "${bucket}" : rule.destination.bucket,
        key: (rule.destination.prefix || "") + _.replace(key, rule.filter.prefix, "")
      }
    }
  }
}

module.exports = {
  stages: {
    tags: {
      index: 0,
      transformers: {
        key: {ref: 'event.Records[0].s3.object.key'},
        bucket: {ref: 'event.Records[0].s3.bucket.name'},
      },
      dependencies: {
        getTags: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObjectTagging'},
            params: {
              explorandaParams: {
                Bucket: { ref: 'stage.bucket'},
                Key: { ref: 'stage.key'},
              }
            }
          },
        }
      },
    },
    process: {
      index: 1,
      transformers: {
        actionConfig: {
          helper: getDestinationFromHighestMatchingRule,
          params: {
            tags: {ref: 'tags.results.getTags.TagSet'}, 
            key: {ref: 'tags.vars.key'},
            eventType: {ref: 'event.Records[0].eventName'},
          },
        },
      },
      dependencies: {
        copy: {
          condition: {ref: 'stage.actionConfig.copy'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.copyObject'},
            params: {
              explorandaParams: {
                CopySource: {ref: 'stage.actionConfig.copySource'},
                Bucket:  {ref: 'stage.actionConfig.bucket' },
                Key: { ref: 'stage.actionConfig.key' },
              }
            }
          },
        },
        delete: {
          condition: {ref: 'stage.actionConfig.delete'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket:  {ref: 'stage.actionConfig.bucket' },
                Key: { ref: 'stage.actionConfig.key' },
              }
            }
          },
        },
      },
    },
  },
}
