const _ = require('lodash')
const = {
  getPostIdFromKey,
  annotatePostList,
  determineUpdates,
} = require('./trail_utils')

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
    determineUpdates: {
      index: 1,
      transformers: {
        values: {
          updates: {
            helper: determineUpdates,
            params: {
              postText: { ref: 'requiredInputs.results.getPost' },
              previousPostList: {
                helper: ({raw}) => {
                  return annotatePostList(raw, '${domain_name}')
                },
                params: {
                  raw: {ref: 'requiredInputs.results.previousPostList'},
                }
              },
              postId: { ref: 'requiredInputs.vars.postId' },
              runningMaterial: { ref: 'requiredInputs.vars.runningMaterial' },
            }
          }
        }
      },
      dependencies: {
        deleteEmptyTrails: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.trailDeleteKeys.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Keys: { ref: 'stage.updates.trailDeleteKeys' },
              }
            }
          },
        },
        deletePostHTML: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.postDeleteKeys.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Keys: { ref: 'stage.updates.postDeleteKeys' },
              }
            }
          },
        },
        saveRenderedPostHTML: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.renderedPost' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Keys: { ref: 'stage.updates.renderedPost.key' },
                Body: { ref: 'stage.updates.renderedPost.rendered' },
              }
            }
          },
        },
        saveRenderedTrailsHTML: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.trailUpdates.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Keys: { 
                  helper: ({updates}) => _.map(updates, 'key'),
                  params: {
                    updates: {ref: 'stage.updates.trailUpdates' },
                  }
                },
                Body: { 
                  helper: ({updates}) => _.map(updates, 'rendered'),
                  params: {
                    updates: {ref: 'stage.updates.trailUpdates' },
                  }
                },
              }
            }
          },
        },
        getPostsToRerender: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.postUpdateKeys.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'stage.bucket'},
                Key: { ref: 'stage.updates.postUpdateKeys' },
              }
            }
          },
        },
        dynamoPuts: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.dynamoPuts.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.putItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${aws_region}'}},
                TableName: '${table}',
                Item: { ref: 'stage.updates.dynamoPuts' }
              }
            }
          }
        },
        dynamoDeletes: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.dynamoDeletes.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.deleteItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: '${aws_region}'}},
                TableName: '${table}',
                Key: { ref: 'stage.updates.dynamoDeletes' }
              }
            }
          }
        },
      }
    },
    neighborUpdates: {
      index: 2,
      condition: {ref: 'determineUpdates.results.getPostsToRerender.length' },
      transformers: {
        postsToRerender: {
          helper: renderChangedPosts,
          params: {
            posts: {ref: 'determineUpdates.results.getPostsToRerender' },
            currentPostList: {ref: 'determineUpdates.vars.updates.newPostList' },
            runningMaterial: { ref: 'requiredInputs.vars.runningMaterial' },
          },
        }
      },
      dependencies: {
        saveRenderedPostsHTML: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.deleteObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Keys: { 
                  helper: ({updates}) => _.map(updates, 'key'),
                  params: {
                    updates: {ref: 'stage.postsToRerender' },
                  }
                },
                Body: { 
                  helper: ({updates}) => _.map(updates, 'rendered'),
                  params: {
                    updates: {ref: 'stage.postsToRerender' },
                  }
                },
              }
            }
          },
        },
      }
    }
  }
}
