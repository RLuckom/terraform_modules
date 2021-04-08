const _ = require('lodash')

const rules = _.sortBy([{"completion_tags":[{"Key":"Archived","Value":"true"}],"destination":{"bucket":"test-human-attention-replica1","manual":true,"prefix":"admin-raphaelluckom-com/uploads/","storage_class":"GLACIER"},"enabled":true,"filter":{"prefix":"uploads/","suffix":"","tags":{}},"priority":0,"replicate_delete":false,"source_bucket":"admin-raphaelluckom-com"},{"completion_tags":[{"Key":"Archived","Value":"true"}],"destination":{"bucket":"test-human-attention-replica2","manual":true,"prefix":"admin-raphaelluckom-com/uploads/","storage_class":"GLACIER"},"enabled":true,"filter":{"prefix":"uploads/","suffix":"","tags":{}},"priority":0,"replicate_delete":false,"source_bucket":"admin-raphaelluckom-com"},{"completion_tags":[{"Key":"Archived","Value":"true"}],"destination":{"bucket":"test-human-attention-replica3","manual":true,"prefix":"admin-raphaelluckom-com/uploads/","storage_class":"GLACIER"},"enabled":true,"filter":{"prefix":"uploads/","suffix":"","tags":{}},"priority":0,"replicate_delete":false,"source_bucket":"admin-raphaelluckom-com"}], 'priority')

function getDestinationsFromMatchingRules({bucket, key, tags, eventType}) {
  const tagObject = _.reduce(tags, (acc, v, k) => {
    acc[v.Key] = v.Value
    return acc
  }, {})
  const applicableRules = _.filter(rules, (rule) => {
    return (
      (_.startsWith(eventType, "ObjectCreated") || (_.startsWith(eventType, "ObjectRemoved") && rule.replicate_delete)) && 
      _.startsWith(key, rule.filter.prefix || "") &&
      _.endsWith(key, rule.filter.suffix || "") &&
      _.reduce(rule.filter.tags, (acc, v, k) => {
        return acc && tagObject[k] === v
      }, true)
    )
  })
  if (applicableRules.length) {
    if (_.startsWith(eventType, "ObjectCreated")) {
        const completionTags =  _.uniqBy(_.flatten(_.map(applicableRules, (rule) => _.get(rule, 'completion_tags'))), 'Key')
      return {
        copy: _.map(applicableRules, () => true),
        storageClass: _.map(applicableRules, (rule) => _.get(rule, 'destination.storage_class') || 'STANDARD'),
        completionTags: completionTags.length ? {TagSet: completionTags} : null,
        bucket: _.map(applicableRules, (rule) => rule.destination.bucket === "" ? "" : rule.destination.bucket),
        copySource: _.map(applicableRules, () => '/' + bucket + '/' + key),
        key: _.map(applicableRules, (rule) => (rule.destination.prefix || "") + _.replace(key, rule.filter.prefix, "")),
      }
    } else if (_.startsWith(eventType, "ObjectRemoved")) {
      return {
        delete: _.map(applicableRules, () => true),
        bucket: _.map(applicableRules, (rule) => rule.destination.bucket === "" ? "" : rule.destination.bucket),
        key: _.map(applicableRules, (rule) => (rule.destination.prefix || "") + _.replace(key, rule.filter.prefix, "")),
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
          condition: {
            helper: ({eventType}) => _.startsWith(eventType, 'ObjectCreated'),
            params: {
              eventType: {ref: 'event.Records[0].eventName'},
            },
          },
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
          helper: getDestinationsFromMatchingRules,
          params: {
            tags: {ref: 'tags.results.getTags.TagSet'}, 
            key: {ref: 'tags.vars.key'},
            bucket: {ref: 'event.Records[0].s3.bucket.name'},
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
                CopySource: { ref: 'stage.actionConfig.copySource'},
                StorageClass: { ref: 'stage.actionConfig.storageClass'},
                Bucket: { ref: 'stage.actionConfig.bucket' },
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
    tagReplicationComplete: {
      condition: {ref: 'process.vars.actionConfig.completionTags'},
      index: 2,
      dependencies: {
        tag: {
          condition: {ref: 'process.vars.actionConfig.copy'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObjectTagging'},
            params: {
              explorandaParams: {
                Key: {ref: 'tags.vars.key'},
                Bucket: {ref: 'event.Records[0].s3.bucket.name'},
                Tagging: {ref: 'process.vars.actionConfig.completionTags'}
              }
            }
          },
        },
      },
    },
  },
}
