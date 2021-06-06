const _ = require('lodash')

module.exports = {
  stages: {
    requiredInputs: {
      index: 0,
      transformers: {
        key: {ref: 'event.Records[0].s3.object.decodedKey'},
        bucket: {ref: 'event.Records[0].s3.bucket.name'},
        postId: {
          helper: getPostIdFromKey,
          params: {
            key: {ref: 'event.Records[0].s3.object.decodedKey'},
          },
        },
        isDelete: {
          helper: isS3Delete,
          params: { 
            eventType: {ref: 'event.Records[0].s3.object.decodedKey'},
          }
        },
        runningMaterial: {
          value: {
            browserRoot: "https://${domain_name}",
            domainName: "${domain_name}",
            postListUrl: "https://${domain_name}/index.html",
            title: "${site_title}",
            navLinks: ${nav_links},
          }
        }
      },
      dependencies: {
        previousPostList: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.query' },
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${aws_region}'}},
                TableName: '${table}',
                ExpressionAttributeValues: {
                  all: {
                    ':typeId': {value: 'post'}
                  }
                },
                KeyConditionExpression: 'type = :typeId'
              }
            },
          }
        },
        getPost: {
          action: 'exploranda',
          condition: {
            not: { ref: 'stage.isDelete' },
          },
          formatter: '[0].Body',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'stage.bucket'},
                Key: { ref: 'stage.key' },
              }
            }
          },
        }
      },
    },
    calculatedValues: {
      index: 1,
      transformers: {
        values: {
        }
      }
    },
    determineUpdates: {
      index: 2,
      transformers: {
        postsToRerender: {
          helper: ({}) => {
          },
          params: {
            currentPostList: { ref: 'requiredInputs.results.currentPostList' },
            postId: { ref: 'requiredInputs.vars.postId' },
            metadata: {ref: 'requiredInputs.vars.metadata' },
          }
        },
        trailsToRerender: {
          helper: ({}) => {
          },
          params: {
            currentPostList: { ref: 'requiredInputs.results.currentPostList' },
            postId: { ref: 'requiredInputs.vars.postId' },
            metadata: {ref: 'requiredInputs.vars.metadata' },
          }
        },
        postRecordsToInsert: {
          helper: ({}) => {
          },
          params: {
            currentPostList: { ref: 'requiredInputs.results.currentPostList' },
            postId: { ref: 'requiredInputs.vars.postId' },
            metadata: {ref: 'requiredInputs.vars.metadata' },
          }
        },
        trailRecordsToInsert: {
          helper: ({}) => {
          },
          params: {
            currentPostList: { ref: 'requiredInputs.results.currentPostList' },
            postId: { ref: 'requiredInputs.vars.postId' },
            metadata: {ref: 'requiredInputs.vars.metadata' },
          }
        },
      },
      dependencies: {
        rerenderPosts: {
          action: 'invokeFunction',
          condition: { ref: 'stage.allUpdates.postsToReRender.length' },
          params: {
            FunctionName: {value: '${post_render_function}'},
            Payload: {
              helper: ({trailUris, bounceDepth}) => {
                return _.map(trailUris, (n) => {
                  return JSON.stringify({
                    item: { uri: n },
                    bounceDepth: bounceDepth ? bounceDepth + 1 : 1
                  })
                })
              },
              params: {
                trailNames: {ref: 'stage.allUpdates.trailsToReRender'},
                bounceDepth: {ref: 'event.bounceDepth'},
              }
            }
          }
        },
        rerenderTrails: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
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
      },
      dependencies: {
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
  },
}
