/*
layers:
  - donut_days
tests: ../spec/src/trails.spec.js
*/
const _ = require('lodash')
const urlTemplate = require('url-template')
const TRAIL_TYPE = 'trail'
const TRAILS_TRAIL_NAME = 'trails'

function checkForEmptyLists({trailsWithDeletedMembers, plannedUpdates}) {
	const {trailsToReRender, neighborsToReRender, dynamoPuts, dynamoDeletes } = plannedUpdates
	const additionalDeletes = []
	_.each(trailsWithDeletedMembers, (trails, i) => {
		if (trails.length < 2) {
			additionalDeletes.push({
        memberKey: `trail:${dynamoDeletes[i].trailName}`,
				trailName: TRAILS_TRAIL_NAME
			})
		}
	})
	return {
		trailsToReRender,
		neighborsToReRender,
		dynamoPuts,
		dynamoDeletes: _.concat(dynamoDeletes, additionalDeletes)
	}
}

function determineUpdates({trails, existingMemberships, existingMembers, siteDescription, item, trailNames}) {
  const updates = {
    neighborsToReRender: [],
    trailsToReRender: [],
    dynamoPuts: [],
    dynamoDeletes: [],
    neighbors: {}
  }
  const trailUriTemplate = urlTemplate.parse(_.get(siteDescription, 'relations.meta.trail.idTemplate'))
  const trailsListId = trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: encodeURIComponent(TRAILS_TRAIL_NAME)}})
  _.each(existingMemberships, (trail) => {
    if (!_.find(trailNames, (name) => name === trail.trailName) && trail.trailName !== TRAILS_TRAIL_NAME) {
      updates.dynamoDeletes.push({
        memberKey: `${item.type}:${item.name}`,
        trailName: trail.trailName
      })
      updates.trailsToReRender.push(trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: trail.trailName}}))
    }
  })
  if (item.type === TRAIL_TYPE && !_.get(existingMembers, 'length')) {
    updates.dynamoDeletes.push({
      memberKey: `${item.type}:${item.name}`,
      trailName: TRAILS_TRAIL_NAME
    })
    updates.trailsToReRender.push(trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: TRAILS_TRAIL_NAME}}))
  }
  _.each(trails, ({members, trailName}) => {
    const trailUriTemplate = urlTemplate.parse(_.get(siteDescription, 'relations.meta.trail.idTemplate'))
    const newList = _.cloneDeep(members)
    const sortedNewList = sortTrailMembers(newList)
    const trailUri = trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: encodeURIComponent(trailName)}})
    const currentIndex = _.findIndex(members, (member) => {
      return member.memberKey === `${item.type}:${item.name}` && _.isEqual(member.memberMetadata, item.metadata)
    })
    const previousIndex = _.findIndex(members, (member) => member.memberUri === item.id)
    if (members.length === 0) {
      updates.dynamoPuts.push({
        trailUri: trailsListId,
        trailName: TRAILS_TRAIL_NAME,
        memberUri: trailUri,
        memberName: trailName,
        memberKey: `trail:${trailName}`,
        memberType: 'trail',
        memberMetadata: {
          date: new Date().toISOString(),
        }
      })
      updates.trailsToReRender.push(trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: trailName}}))
    }
    if (currentIndex === -1) {
      const trailMember = {
        trailUri: trailUri,
        trailName,
        memberUri: item.uri,
        memberName: item.name,
        memberKey: `${item.type}:${item.name}`,
        memberType: item.type,
        memberMetadata: item.metadata
      }
      newList.push(trailMember)
      updates.trailsToReRender.push(trailUriTemplate.expand({...siteDescription.siteDetails, ...{name: trailName}}))
      updates.dynamoPuts.push(trailMember)
      const newIndex = sortedNewList.findIndex((i) => i.memberUri === item.id && _.isEqual(i.memberMetadata, item.metadata))
      if (previousIndex !== -1 && newIndex !== previousIndex) {
        updates.neighborsToReRender.push(members[previousIndex + 1])
        updates.neighborsToReRender.push(members[previousIndex - 1])
        newList.splice(previousIndex, 1)
      }
      updates.neighborsToReRender.push(sortedNewList[newIndex + 1])
      updates.neighborsToReRender.push(sortedNewList[newIndex - 1])
      updates.neighbors[trailName] = {
        trailName,
        previousNeighbor: sortedNewList[newIndex + 1] || null,
        nextNeighbor: sortedNewList[newIndex - 1] || null,
      }
    } else {
      updates.neighbors[trailUri] = {
        trailName,
        previousNeighbor: sortedNewList[currentIndex + 1] || null,
        nextNeighbor: sortedNewList[currentIndex - 1] || null,
      }
    }
  })
  updates.trailsToReRender = _.uniq(updates.trailsToReRender)
  updates.neighborsToReRender = _(updates.neighborsToReRender).filter().uniqWith((arg1, arg2) => {
    return arg1.memberUri === arg2.memberUri && arg2.memberType === arg2.memberType
  }).value()
  updates.dynamoPuts = _(updates.dynamoPuts).uniq().filter().value()
  updates.dynamoDeletes = _(updates.dynamoDeletes).uniq().filter().value()
  return updates
} 

function sortTrailMembers(members) {
  return _(members).sortBy((m) => _.get(m, 'memberMetadata.date') || _.get(m, 'memberMetadata.frontMatter.date')).reverse().value()
}

module.exports = {determineUpdates, checkForEmptyLists, sortTrailMembers}
