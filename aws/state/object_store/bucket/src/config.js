const _ = require('lodash')

const getObjectTagging = {
  dataSource: 'AWS',
  namespaceDetails: {
    name: 'S3',
    constructorArgs: {}
  },
  name: 'getObjectTagging',
  value: {
    path: _.identity,
  },
  apiMethod: 'getObjectTagging',
  requiredParams: {
    Bucket: {},
    Key: {},
  },
};

const rules = _.sortBy(${rules}, 'priority')

function getDestinationFromHighestMatchingRule({key, tags}) {
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
  console.log(rule)
  if (rule) {
    return {
      bucket: rule.destination.bucket,
      copySource: '/${bucket}/' + key,
      key: (rule.destination.prefix || "") + _.replace(key, rule.filter.prefix, "")
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
            accessSchema: {value: getObjectTagging},
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
    copy: {
      index: 1,
      transformers: {
        copyConfig: {
          helper: getDestinationFromHighestMatchingRule,
          params: {
            tags: {ref: 'tags.results.getTags.TagSet'}, 
            key: {ref: 'tags.vars.key'},
          },
        },
      },
      dependencies: {
        copy: {
          condition: {ref: 'stage.copyConfig'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.copyObject'},
            params: {
              explorandaParams: {
                CopySource: {ref: 'stage.copyConfig.copySource'},
                Bucket:  {ref: 'stage.copyConfig.bucket' },
                Key: { ref: 'stage.copyConfig.key' },
              }
            }
          },
        }
      },
    },
  },
}
