const _ = require('lodash')
const {
  isS3Delete,
  renderChangedPosts,
  getPostIdFromKey,
  annotatePostList,
  determineUpdates,
} = require('./helpers/render_utils')

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
            eventType: {ref: 'event.Records[0].eventName'},
          }
        },
        runningMaterial: {
          value: {
            browserRoot: "https://${domain_name}",
            domainName: "${domain_name}",
            paymentPointer: "${payment_pointer}",
            postListUrl: "https://${domain_name}/index.html",
            title: "${site_title}",
            navLinks: ${nav_links},
            relMeLink: ${rel_me_link.href == "" ? "null" : jsonencode(rel_me_link)}
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
                TableName: '${table_name}',
                ExpressionAttributeValues: {
                  all: {
                    ':kindId': {value: 'post'}
                  }
                },
                KeyConditionExpression: 'kind = :kindId'
              }
            },
          }
        },
        getPost: {
          action: 'exploranda',
          condition: {
            not: { ref: 'stage.isDelete' },
          },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'stage.bucket'},
                Key: { ref: 'stage.key' },
              }
            }
          },
        },
        getPostTemplate: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'stage.bucket'},
                Key: { value: '${post_template_key}' },
              }
            }
          },
        },
        getTrailTemplate: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'stage.bucket'},
                Key: { value: '${trail_template_key}' },
              }
            }
          },
        }
      },
    },
    determineUpdates: {
      index: 1,
      transformers: {
        updates: {
          helper: determineUpdates,
          params: {
            postText: { ref: 'requiredInputs.results.getPost[0].Body' },
            previousPostList: {
              helper: ({raw}) => {
                return annotatePostList(raw, '${domain_name}')
              },
              params: {
                raw: {ref: 'requiredInputs.results.previousPostList'},
              }
            },
            postId: { ref: 'requiredInputs.vars.postId' },
            isDelete: { ref: 'requiredInputs.vars.isDelete' },
            runningMaterial: { ref: 'requiredInputs.vars.runningMaterial' },
            postTemplate: { ref: 'requiredInputs.results.getPostTemplate[0].Body' },
            trailTemplate: { ref: 'requiredInputs.results.getTrailTemplate[0].Body' },
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
                Key: { ref: 'stage.updates.trailDeleteKeys' },
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
                Key: { ref: 'stage.updates.postDeleteKeys' },
              }
            }
          },
        },
        saveRenderedPostHTML: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.renderedPost' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                Key: { ref: 'stage.updates.renderedPost.key' },
                ContentType: { value: 'text/html; charset=utf-8' },
                Body: { ref: 'stage.updates.renderedPost.rendered' },
              }
            }
          },
        },
        saveRenderedTrailsHTML: {
          action: 'exploranda',
          condition: { ref: 'stage.updates.trailUpdates.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                ContentType: { value: 'text/html; charset=utf-8' },
                Key: { 
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
                Bucket: {ref: 'requiredInputs.vars.bucket'},
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
                TableName: '${table_name}',
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
                TableName: '${table_name}',
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
            posts: {
              helper: ({posts, keys}) => _.map(posts, (p, indx) => {
                return {
                  text: p.Body.toString('utf8'),
                  id: getPostIdFromKey({key: keys[indx]})
                }
              }),
              params: {
                posts: {ref: 'determineUpdates.results.getPostsToRerender' },
                keys: { ref: 'determineUpdates.vars.updates.postUpdateKeys' },
              }
            },
            currentPostList: {ref: 'determineUpdates.vars.updates.newPostList' },
            runningMaterial: { ref: 'requiredInputs.vars.runningMaterial' },
            postTemplate: { ref: 'requiredInputs.results.getPostTemplate[0].Body' },
          },
        }
      },
      dependencies: {
        saveRenderedPostsHTML: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObject'},
            params: {
              explorandaParams: {
                Bucket: {ref: 'requiredInputs.vars.bucket'},
                ContentType: { value: 'text/html; charset=utf-8' },
                Key: {
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
