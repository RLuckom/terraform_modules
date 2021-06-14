const _ = require('lodash')
const yaml = require('js-yaml')

const blogImageKeyRegExp = new RegExp('${blog_image_hosting_prefix}([^/]*)/([^\.]*)/([0-9]*)\.(.*)')
const pluginImageKeyRegExp = new RegExp('${blog_image_hosting_prefix}([^/]*)/([^\.]*)/([0-9]*)\.(.*)')

function parsePost(s) {
  const t = s.split('\n')
  if (_.trim(t[0]) === '---') {
    let started = false
    let frontMatter = ''
    let content = ''
    for (r of t.slice(1)) {
      if (_.trim(r) === '---') {
        if (!started) {
          started = true
        } else {
          content += r + "\n"
        }
      } else {
        if (started) {
          content += r + "\n"
        } else {
          frontMatter += r + '\n'
        }
      }
    }
    try {
      const fm = yaml.load(frontMatter)
      return { frontMatter: fm, content, raw:s }
    } catch(e) {
      console.error(e)
      return { raw: s} 
    }
  } else {
    return { raw: s }
  }
}

function postRecordToDynamo(id, pr) {
  return {kind: 'post', id, frontMatter: pr.frontMatter}
}

function serializePostToMarkdown({frontMatter, content}) {
  let text = '---\n' + yaml.dump(frontMatter) + '---\n' + content
  return text
}

module.exports = {
  stages: {
    parsePost: {
      index: 0,
      transformers: {
        postId: {
          helper: ({pluginKey}) => {
            const parts = pluginKey.split('/').pop().split('.')
            parts.pop()
            return parts.join('.')
          },
          params: {
            pluginKey: {ref: 'event.Records[0].s3.object.decodedKey'},
          }
        }
      },
      dependencies: {
        current: {
          action: 'exploranda',
          formatter: ({current}) => {
            return parsePost(current[0].Body.toString('utf8'))
          },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            explorandaParams: {
              Bucket: {ref: 'event.Records[0].s3.bucket.name'},
              Key: {ref: 'event.Records[0].s3.object.decodedKey'},
            }
          },
        },
        previous: {
          action: 'exploranda',
          formatter: ({previous}) => {
            if (previous.length) {
              return parsePost(previous[0].Body.toString('utf8'))
            }
            return null
          },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            behaviors: { value: {
              onError: (e, r) => {
                return {
                  err: null,
                  res: []
                }
              }
            }},
            explorandaParams: {
              Bucket: {value: '${website_bucket}'},
              Key: {
                helper: ({postId}) => "${blog_post_hosting_prefix}" + postId + '.md',
                params: {
                  postId: {ref: 'stage.postId'},
                }
              },
            }
          },
        },
        availableImages: {
          action: 'exploranda',
          formatter: ({availableImages}) => {
            return _.map(_.flatten(availableImages), ({Key}) => {
              const [match, postId, imageId, size, ext] = pluginImageKeyRegExp.exec(Key)
              return {key: Key, postId, imageId, size, ext}
            })
          },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.listObjects'},
            explorandaParams: {
              Bucket: {ref: 'event.Records[0].s3.bucket.name'},
              Prefix: {
                helper: ({postId}) => "${plugin_image_hosting_prefix}" + postId,
                params: {
                  postId: {ref: 'stage.postId'},
                }
              }
            }
          },
        },
        publishedImages: {
          action: 'exploranda',
          formatter: ({publishedImages}) => {
            return _.map(_.flatten(publishedImages), ({Key}) => {

              const [key, postId, imageId, size, ext] = blogImageKeyRegExp.exec(Key) 
              return {key, postId, imageId, size, ext}
            })
          },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.listObjects'},
            explorandaParams: {
              Bucket: {value: '${website_bucket}'},
              Prefix: {
                helper: ({postId}) => "${blog_image_hosting_prefix}" + postId,
                params: {
                  postId: {ref: 'stage.postId'},
                }
              }
            }
          },
        },
      }
    },
    publish: {
      index: 1,
      transformers: {
        publish: {
          helper: ({publish, unpublish}) => publish && !unpublish,
          params: {
            publish: {ref: 'parsePost.results.current.frontMatter.publish' },
            unpublish: {ref: 'parsePost.results.current.frontMatter.unpublish' },
          }
        },
        delete: {ref: 'parsePost.results.current.frontMatter.delete' },
        unpublish: {ref: 'parsePost.results.current.frontMatter.unpublish' },
        imagesToUnpublish: {
          helper: ({publishedImages, unpublish, del, currentImageIds}) => {
            if (unpublish || del) {
              return publishedImages
            } else {
              return _.filter(publishedImages, ({imageId}) => (currentImageIds || []).indexOf(imageId) === -1)
            }
          },
          params: {
            unpublish: {ref: 'parsePost.results.current.frontMatter.unpublish' },
            del: {ref: 'parsePost.results.current.frontMatter.delete' },
            currentImageIds: {ref: 'parsePost.results.current.frontMatter.meta.imageIds' },
            publishedImages: {ref: 'parsePost.results.publishedImages' },
          }
        },
        imagesToDelete: {
          helper: ({availableImages, currentImageIds, del}) => {
            if (del) {
              return availableImages
            }
            return _.filter(availableImages, ({imageId}) => {
              return currentImageIds.indexOf(imageId) === -1
            })
          },
          params: {
            currentImageIds: {ref: 'parsePost.results.current.frontMatter.meta.imageIds' },
            availableImages: {ref: 'parsePost.results.availableImages' },
            del: {ref: 'parsePost.results.current.frontMatter.delete' },
          }
        },
        imagesToPublish: {
          helper: ({unpublish, del, publish, currentImageIds, availableImages}) => {
            if (unpublish || !publish || del) {
              return []
            } else {
              return _.filter(availableImages, ({imageId}) => currentImageIds.indexOf(imageId) !== -1)
            }
          },
          params: {
            publish: {ref: 'parsePost.results.current.frontMatter.publish' },
            unpublish: {ref: 'parsePost.results.current.frontMatter.unpublish' },
            del: {ref: 'parsePost.results.current.frontMatter.delete' },
            availableImages: {ref: 'parsePost.results.availableImages' },
            currentImageIds: {ref: 'parsePost.results.current.frontMatter.meta.imageIds' },
          }
        },
        dynamoPuts: {
          helper: ({post, postId, isDelete}) => {
            if (!isDelete) {
              return [postRecordToDynamo(postId, post)]
            }
            return []
          },
          params: {
            isDelete: {ref: 'parsePost.results.current.frontMatter.delete' },
            post: {ref: 'parsePost.results.current' },
            postId: {ref: 'parsePost.vars.postId'},
          }
        },
      },
      dependencies: {
        dynamoPuts: {
          action: 'exploranda',
          condition: { ref: 'stage.dynamoPuts.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.putItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${table_region}'}},
                TableName: '${table_name}',
                Item: { ref: 'stage.dynamoPuts' }
              }
            }
          }
        },
        savePost: {
          action: 'exploranda',
          condition: {not: { ref: 'stage.delete' }},
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObject'},
            explorandaParams: {
              Bucket: {ref: 'event.Records[0].s3.bucket.name'},
              Key: {
                helper: ({pluginKey}) => _.replace(pluginKey, "${plugin_post_upload_prefix}", "${plugin_post_hosting_prefix}"),
                  params: {
                  pluginKey: {ref: 'event.Records[0].s3.object.decodedKey'},
                }
              },
              ContentType: { value: 'text/markdown' },
              Body: {ref: 'parsePost.results.current.raw' },
            }
          },
        },
        deletePost: {
          action: 'exploranda',
          condition: { ref: 'stage.delete' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            explorandaParams: {
              Bucket: {ref: 'event.Records[0].s3.bucket.name'},
              Key: {
                helper: ({pluginKey}) => _.replace(pluginKey, "${plugin_post_upload_prefix}", "${plugin_post_hosting_prefix}"),
                params: {
                  pluginKey: {ref: 'event.Records[0].s3.object.decodedKey'},
                }
              },
            }
          },
        },
        publishPost: {
          action: 'exploranda',
          condition: { ref: 'stage.publish' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObject'},
            explorandaParams: {
              Bucket: {value: '${website_bucket}'},
              Key: {
                helper: ({pluginKey}) => "${blog_post_hosting_prefix}" + pluginKey.split('/').pop(),
                  params: {
                  pluginKey: {ref: 'event.Records[0].s3.object.decodedKey'},
                }
              },
              ContentType: { value: 'text/markdown' },
              Body: {
                helper: ({parsed, postId}) => {
                 const postString = serializePostToMarkdown(parsed) 
                 return _.replace(postString, "${plugin_image_hosting_root}", "${blog_image_hosting_root}")
                 .replace(new RegExp("\\((https:\/\/.*)" + postId + '([^\\)]*)\\)', 'g'), (match, g1, g2) => "(" + g1 + encodeURIComponent(postId) + g2 + ')')
                 .replace(new RegExp("]\\(/(.*)" + postId + '([^\\)]*)\\)', 'g'), (match, g1, g2) => "](/" + g1 + encodeURIComponent(postId) + g2 + ')')
                },
                params: {
                  postId: {ref: 'parsePost.vars.postId'},
                  parsed: {ref: 'parsePost.results.current' },
                }
              }
            }
          },
        },
        unpublishPost: {
          action: 'exploranda',
          condition: {or: [
            { ref: 'stage.unpublish' },
            { ref: 'stage.delete' },
          ]},
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            explorandaParams: {
              Bucket: {value: '${website_bucket}'},
              Key: {
                helper: ({pluginKey}) => "${blog_post_hosting_prefix}" + pluginKey.split('/').pop(),
                params: {
                  pluginKey: {ref: 'event.Records[0].s3.object.decodedKey'},
                }
              },
            }
          },
        },
      }
    },
    manageImages: {
      index: 2,
      dependencies: {
        publish: {
          action: 'exploranda',
          condition: {ref: 'publish.vars.imagesToPublish.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.copyObject'},
            explorandaParams: {
              Bucket: {value: '${website_bucket}'},
              CopySource: {
                helper: ({images, bucket}) => _.map(images, ({key}) => "/" + bucket + "/" + key),
                params: {
                  images: {ref: 'publish.vars.imagesToPublish' },
                  bucket: {ref: 'event.Records[0].s3.bucket.name'},
                }
              },
              Key: {
                helper: ({images}) => _.map(images, ({key}) => _.replace(key, "${plugin_image_hosting_prefix}", "${blog_image_hosting_prefix}")),
                  params: {
                  images: {ref: 'publish.vars.imagesToPublish' },
                }
              }
            }
          },
        },
        unpublish: {
          action: 'exploranda',
          condition: {ref: 'publish.vars.imagesToUnpublish.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            explorandaParams: {
              Bucket: {
                helper: ({images, bucket}) => {
                  const n = _.map(images, (id) => bucket)
                  return n
                },
                params: {
                  images: {ref: 'publish.vars.imagesToUnpublish' },
                  bucket: {value: '${website_bucket}'},
                }
              },
              Key: {
                helper: ({images}) => {
                  const n = _.map(images, 'key')
                  return n
                },
                params: {
                  images: {ref: 'publish.vars.imagesToUnpublish' },
                }
              }
            }
          },
        },
        delete: {
          action: 'exploranda',
          condition: {ref: 'publish.vars.imagesToDelete.length'},
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            explorandaParams: {
              Bucket: {
                helper: ({images, bucket}) => {
                  const n = _.map(images, (id) => bucket)
                  return n
                },
                params: {
                  images: {ref: 'publish.vars.imagesToDelete' },
                  bucket: {ref: 'event.Records[0].s3.bucket.name'},
                }
              },
              Key: {
                helper: ({images}) => {
                  const n = _.map(images, 'key')
                  return n
                },
                params: {
                  images: {ref: 'publish.vars.imagesToDelete' },
                }
              }
            }
          },
        },
      }
    },
    cleanupDB: {
      index: 3,
      transformers: {
        dynamoDeletes: {
          helper: ({postId, isDelete}) => {
            if (isDelete) {
              return [{kind: 'post', id: postId}]
            }
            return []
          },
          params: {
            isDelete: {ref: 'parsePost.results.current.frontMatter.delete' },
            postId: {ref: 'parsePost.vars.postId'},
          }
        },
      },
      dependencies: {
        dynamoDeletes: {
          action: 'exploranda',
          condition: { ref: 'stage.dynamoDeletes.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.deleteItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${table_region}'}},
                TableName: '${table_name}',
                Key: { ref: 'stage.dynamoDeletes' }
              }
            }
          }
        },
      }
    }
  },
}
