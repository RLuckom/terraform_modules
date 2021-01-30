const _ = require('lodash')
const urlTemplate = require('url-template')
const { siteDescriptionDependency } = require('./helpers/idUtils')
const formatters = require('./helpers/formatters')
const trails = require('./helpers/trails.js')

module.exports = {
  cleanup: {
    transformers: {
      trails: { 
        all: {
          neighbors: {ref: 'determineUpdates.vars.updates.neighbors' },
          members: {ref: 'updateDependencies.results.existingMembers' },
        }
      }
    },
  },
  stages: {
    siteDescription: {
      index: 0,
      dependencies: {
        siteDescription: siteDescriptionDependency('${domain_name}', '${site_description_path}')
      },
    },
    updateDependencies: {
      index: 1,
      transformers: {
        trails: {
          helper: 'idUtils.expandUrlTemplateWithNames',
          params: {
            templateString: {ref: 'siteDescription.results.siteDescription.${self_type}.setTemplate'},
            siteDetails: {ref: 'siteDescription.results.siteDescription.siteDetails'},
            names: {ref: 'event.trailNames'},
          }
        },
        existingMemberships: {
          helper: 'idUtils.expandUrlTemplateWithName',
          params: {
            templateString: {ref: 'siteDescription.results.siteDescription.${self_type}.membersTemplate'},
            siteDetails: {ref: 'siteDescription.results.siteDescription.siteDetails'},
            name: {ref: 'event.item.name'},
            type: {ref: 'event.item.type'},
          }
        },
        existingMembers: {
          helper: 'idUtils.expandUrlTemplateWithName',
          condition: {
            matches: {
              a: {ref: 'event.item.type'},
              b: {value: 'trail'},
            }
          },
          params: {
            templateString: {ref: 'siteDescription.results.siteDescription.${self_type}.setTemplate'},
            siteDetails: {ref: 'siteDescription.results.siteDescription.siteDetails'},
            name: {ref: 'event.item.name'},
          }
        },
      },
      dependencies: {
        trails: {
          action: 'genericApi',
          condition: { ref: 'stage.trails.length'},
          formatter: formatters.singleValue.unwrapJsonHttpResponseArray,
          params: {
            url: { ref: 'stage.trails' }
          }
        },
        existingMemberships: {
          condition: { ref: 'stage.existingMemberships'},
          action: 'genericApi',
          formatter: formatters.singleValue.unwrapJsonHttpResponse,
          params: {
            url: { ref: 'stage.existingMemberships'}
          }
        },
        existingMembers: {
          action: 'genericApi',
          condition: { ref: 'stage.existingMembers'},
          formatter: {
            helper: 'formatters.multiStepFomatter',
            params: {
              preformatter: formatters.singleValue.unwrapJsonHttpResponse,
              formatter: trails.sortTrailMembers 
            },
          },
          params: {
            url: { ref: 'stage.existingMembers'}
          }
        }
      },
    },
    parseLists: {
      index: 2,
      transformers: {
        trails: { 
          helper: 'transform',
          params: {
            arg: {
              all: {
                trailArrays: {ref: 'updateDependencies.results.trails' },
                trailUrls: {ref: 'updateDependencies.vars.trails' },
                trailNames: {ref: 'event.trailNames'},
              }
            },
            func: {value: ({trailUrls, trailNames, trailArrays}) => {
              return _.reduce(trailUrls, (a, trailUrl, index) => {
                a[trailUrl] = {
                  members: trails.sortTrailMembers(trailArrays[index]),
                  trailName: trailNames[index]
                }
                return a
              }, {})
            } }
          }
        },
      }
    },
    determineUpdates: {
      index: 3,
      transformers: {
        updates: {
          helper: 'transform',
          params: {
            arg: {
              all: {
                trails: { ref: 'parseLists.vars.trails' },
                trailNames: {ref: 'event.trailNames'},
                existingMemberships: { ref: 'updateDependencies.results.existingMemberships' },
                siteDescription: { ref: 'siteDescription.results.siteDescription' }, 
                item: { ref: 'event.item' },
              }
            },
            func: { value: trails.determineUpdates }
          }
        }
      },
      dependencies: {
        trailsWithDeletedMembers: {
          condition: { ref: 'stage.updates.dynamoDeletes.length'},
          action: 'genericApi',
          formatter: formatters.singleValue.unwrapJsonHttpResponseArray,
          params: {
            mergeIndividual: _.identity,
            url: {
              helper: 'transform',
              params: {
                arg: {
                  all: {
                    deletes: { ref: 'stage.updates.dynamoDeletes'},
                    siteDescription: { ref: 'siteDescription.results.siteDescription' }, 
                  }
                },
                func: ({deletes, siteDescription}) => {
                  const trailUriTemplate = urlTemplate.parse(_.get(siteDescription, '${self_type}.setTemplate'))
                  return _.map(deletes, ({trailName}) => {
                    return trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: encodeURIComponent(trailName)}})
                  })
                }
              }
            }
          }
        }
      }
    },
    checkForEmptyLists: {
      index: 4,
      transformers: {
        allUpdates: {
          helper: 'transform',
          params: {
            arg: {
              all: {
                plannedUpdates: { ref: 'determineUpdates.vars.updates' },
                trailsWithDeletedMembers: {ref: 'determineUpdates.results.trailsWithDeletedMembers' }
              }
            },
            func: {
              value: trails.checkForEmptyLists,
            }
          }
        }
      },
      dependencies: {
        dynamoPuts: {
          action: 'exploranda',
          condition: { ref: 'stage.allUpdates.dynamoPuts.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.putItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: 'us-east-1'}},
                TableName: '${table}',
                Item: { ref: 'stage.allUpdates.dynamoPuts' }
              }
            }
          }
        },
        dynamorDeletes: {
          action: 'exploranda',
          condition: { ref: 'stage.allUpdates.dynamoDeletes.length' },
          params: {
            accessSchema: {value: 'dataSources.AWS.dynamodb.deleteItem'},
            params: {
              explorandaParams: {
                apiConfig: {value: {region: 'us-east-1'}},
                TableName: '${table}',
                Key: { ref: 'stage.allUpdates.dynamoDeletes' }
              }
            }
          }
        },
        rerenderNeighbors: {
          action: 'invokeFunction',
          condition: { ref: 'stage.allUpdates.neighborsToReRender.length' },
          params: {
            FunctionName: {value: '${render_function}'},
            Payload: { 
              helper: 'transform', 
              params: {
                arg: {
                  all: {
                    neighbors: {ref: 'stage.allUpdates.neighborsToReRender'},
                    bounceDepth: {ref: 'event.bounceDepth'},
                  }
                },
                func: ({neighbors, bounceDepth}) => {
                  return _.map(neighbors, (n) => {
                    return JSON.stringify({
                      item: n,
                      bounceDepth: bounceDepth + 1
                    })
                  })
                },
              }
            }
          }
        },
        rerenderTrails: {
          action: 'invokeFunction',
          condition: { ref: 'stage.allUpdates.trailsToReRender.length' },
          params: {
            FunctionName: {value: '${render_function}'},
            Payload: { 
              helper: 'transform', 
              params: {
                arg: {
                  all: {
                    trailUris: {ref: 'stage.allUpdates.trailsToReRender'},
                    bounceDepth: {ref: 'event.bounceDepth'},
                  }
                },
                func: ({trailUris, bounceDepth}) => {
                  return _.map(trailUris, (n) => {
                    return JSON.stringify({
                      item: { uri: n },
                      bounceDepth: bounceDepth + 1
                    })
                  })
                },
              }
            }
          }
        },
      },
    },
  }
}
