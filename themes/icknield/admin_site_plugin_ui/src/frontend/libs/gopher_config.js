const POLL_INTERVAL = 2000
window.GOPHER_CONFIG = {
  awsDependencies: {
    postRecords: {
      accessSchema: exploranda.dataSources.AWS.dynamodb.query,
      params: {
        apiConfig: {value: {region: '${aws_region}'}},
        TableName: {value: CONFIG.posts_table},
        ExpressionAttributeValues: {
          value: {
            ':kindId': 'post',
          }
        },
        KeyConditionExpression: {value: 'kind = :kindId' },
      },
    },
    putImage: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          input: 'buffer',
          formatter: ({buffer}) => {
            return buffer
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        Key: { 
          input: ['imageExt', 'postId', 'imageId'],
          formatter: ({imageExt, postId, imageId}) => {
            return getImageUploadKey({postId, imageId, imageExt})
          }
        },
      }
    },
    getPost: {
      accessSchema: exploranda.dataSources.AWS.s3.getObject,
      formatter: ([post], {postId}) => {
        let parsed
        if (post) {
          parsed = parsePost(post.Body.toString('utf8'))
          parsed.etag = post.ETag
          parsed.lastSaved = post.LastModified
          parsed.frontMatter.createDate = parsed.frontMatter.createDate || parsed.frontMatter.date || new Date().toISOString(),
          setPostAsSaved(postId, parsed)
        }
        return parsed
      },
      params: {
        Bucket: {value: CONFIG.private_storage_bucket },
        ResponseCacheControl: {value: 'no-cache'},
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostHostingKey({postId})
          }
        },
      },
      behaviors: {
        maybeNull: true,
        detectErrors: (err, res) => {
          if (err && err.name === "NoSuchKey") {
            return
          }
          if (err || !res) {
            return err
          }
        }
      }
    },
    saveAndPublishPostWithoutInput: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          source: 'getPost',
          input: 'postId',
          formatter: ({getPost}, {postId}) => {
            const postToSend = _.cloneDeep(latestKnownPostState(postId))
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            delete postToSend.frontMatter.unpublish
            delete postToSend.frontMatter.delete
            postToSend.frontMatter.publish = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    unpublishPostWithoutInput: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          source: 'getPost',
          input: 'postId',
          formatter: ({getPost}, {postId}) => {
            const postToSend = _.cloneDeep(latestKnownPostState(postId))
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            delete postToSend.frontMatter.publish
            delete postToSend.frontMatter.delete
            postToSend.frontMatter.unpublish = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    deletePostWithoutInput: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          source: ['getPost', 'unpublishPostWithoutInput', 'confirmPostUnpublished'],
          formatter: ({getPost}) => {
            const postToSend = _.cloneDeep(getPost)
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            delete postToSend.frontMatter.publish
            delete postToSend.frontMatter.unpublish
            postToSend.frontMatter.delete = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    savePostWithoutPublishing: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          input: 'post',
          formatter: ({post}) => {
            const postToSend = _.cloneDeep(post)
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            postToSend.frontMatter.updateDate = new Date().toISOString(),
            postToSend.frontMatter.date = new Date().toISOString(),
            delete postToSend.frontMatter.publish
            delete postToSend.frontMatter.unpublish
            delete postToSend.frontMatter.delete
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    saveAndPublishPost: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          input: 'post',
          formatter: ({post}) => {
            const postToSend = _.cloneDeep(post)
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            postToSend.frontMatter.updateDate = new Date().toISOString(),
            postToSend.frontMatter.date = new Date().toISOString(),
            delete postToSend.frontMatter.unpublish
            delete postToSend.frontMatter.delete
            postToSend.frontMatter.publish = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    postImageList: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      params: {
        Bucket: {value: [CONFIG.private_storage_bucket]},
        Prefix: {
          input: 'postId', 
          formatter: ({postId}) => {
            return CONFIG.plugin_image_hosting_prefix + postId
          }
        },
      },
    },
    confirmImagesPublished: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      params: {
        Bucket: {value: [CONFIG.website_bucket]},
        Prefix: {
          input: 'postId', 
          formatter: ({postId}) => {
            return CONFIG.blog_image_hosting_prefix + postId
          }
        },
        MaxKeys: {
          source: 'postImageList',
          formatter: ({postImageList}) => {
            return (_.flatten(postImageList).length + 1) * 10
          }
        }
      },
      behaviors: {
        retryParams: {
          times: 10,
          interval: (n) => n * POLL_INTERVAL
        },
        detectErrors: (err, res, {MaxKeys}) => {
          return res.Contents.length !== ((MaxKeys / 10) - 1)
        }
      }
    },
    getPublishedPostETag: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      formatter: ([postRecord]) => {
        return _.get(postRecord, '[0].ETag')
      },
      params: {
        Bucket: { value: [CONFIG.website_bucket]},
        Prefix: {
          input: 'postId', 
          formatter: ({postId}) => {
            return getPostPublicKey({postId})
          }
        },
      },
      behaviors: {
        maybeNull: true,
      }
    },
    confirmPostPublished: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      params: {
        Bucket: {
          source: 'confirmImagesPublished',
          formatter: () => [CONFIG.website_bucket],
        },
        Prefix: {
          input: 'postId', 
          formatter: ({postId}) => {
            return CONFIG.blog_post_hosting_prefix + postId
          }
        },
      },
      behaviors: {
        retryParams: {
          times: 10,
          interval: (n) => n * POLL_INTERVAL
        },
        detectErrors: (err, res) => {
          return res.Contents.length !== 2
        }
      }
    },
    unpublishPost: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          input: 'post',
          formatter: ({post}) => {
            const postToSend = _.cloneDeep(post)
            postToSend.frontMatter.createDate = postToSend.frontMatter.createDate || postToSend.frontMatter.date || new Date().toISOString(),
            postToSend.frontMatter.updateDate = new Date().toISOString(),
            postToSend.frontMatter.date = new Date().toISOString(),
            delete postToSend.frontMatter.publish
            delete postToSend.frontMatter.delete
            postToSend.frontMatter.unpublish = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    deletePost: {
      accessSchema: exploranda.dataSources.AWS.s3.putObject,
      params: {
        Body: {
          input: 'post',
          formatter: ({post}) => {
            const postToSend = _.cloneDeep(post)
            delete postToSend.frontMatter.publish
            delete postToSend.frontMatter.unpublish
            postToSend.frontMatter.delete = true
            return serializePost(postToSend)
          }
        },
        Bucket: {value: CONFIG.private_storage_bucket },
        ContentType: { value: 'text/markdown' },
        Key: { 
          input: 'postId',
          formatter: ({postId}) => {
            return getPostUploadKey({postId})
          }
        },
      }
    },
    listPosts: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      formatter: (posts) => {
        return _.filter(_.flatten(posts), (post) => {
          return _.endsWith(post.Key, '.md')
        })
      },
      params: {
        Bucket: {value: CONFIG.private_storage_bucket },
        Prefix: { value: CONFIG.plugin_post_hosting_path },
      }
    },
    confirmPostUnpublished: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      params: {
        Bucket: {value: [CONFIG.website_bucket, CONFIG.website_bucket]},
        Prefix: {
          input: 'postId', 
          formatter: ({postId}) => {
            return [
              CONFIG.blog_image_hosting_prefix + postId,
              CONFIG.blog_post_hosting_prefix + postId,
            ]
          }
        },
      },
      behaviors: {
        retryParams: {
          times: 10,
          interval: (n) => n * POLL_INTERVAL
        },
        detectErrors: (err, res) => {
          return res.Contents.length
        }
      }
    },
    confirmPostDeleted: {
      accessSchema: exploranda.dataSources.AWS.s3.listObjects,
      params: {
        Bucket: {value: [CONFIG.private_storage_bucket, CONFIG.private_storage_bucket]},
        Prefix: {
          input: ['postId'],
          formatter: ({postId}) => {
            return [
              CONFIG.plugin_image_hosting_prefix + postId,
              CONFIG.plugin_post_hosting_prefix + postId,
            ]
          }
        },
      },
      behaviors: {
        retryParams: {
          times: 10,
          interval: (n) => n * POLL_INTERVAL
        },
        detectErrors: (err, res) => {
          return res.Contents.length
        }
      }
    },
  },
  otherDependencies: {
    pollImage: {
      accessSchema: {
        name: 'GET url',
        dataSource: 'GENERIC_API',
        value: {path:  _.identity},
      },
      params: {
        apiConfig: {
          input: ['imageExt', 'postId', 'imageId', 'imageSize'],
          formatter: ({imageExt, postId, imageId, imageSize}) => {
            return {
              method: 'GET',
              url: getImagePrivateUrl({postId, imageId, ext: imageExt, size: imageSize})
            }
          },
        },
        dependency: {
          source: 'putImage',
          formatter: _.identity
        }
      },
      behaviors: {
        retryParams: {
          errorFilter: (err) => {
            return err === 404
          },
          times: 10,
          interval: (n) => n * POLL_INTERVAL
        },
        detectErrors: (err, res) => {
          if (err || !res) {
            return err
          }
        }
      }
    },
  },
}
