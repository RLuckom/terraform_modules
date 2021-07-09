window.RENDER_CONFIG = {
  smallScreenFormatters: {
    toggleTray: () => {
      function toggleTray (evt) {
        evt.target.closest('.post-list-entry').classList.toggle('open')
      }
      function revert() {
        _.map(
          document.querySelectorAll('.post-list-entry'),
          (el) => {
            el.removeEventListener('click', toggleTray)
          }
        )
      }
      _.map(
        document.querySelectorAll('.post-list-entry'),
        (el) => {
          el.addEventListener('click', toggleTray)
        }
      )
      return revert
    }
  },
  init: ({listPosts, postRecords, pageHits}, gopher) => {
    const mainSection = document.querySelector('main')
    const closeInputButtonText = 'X'
    window.addEventListener('pageshow', () => {
      goph.report(['listPosts', 'postRecords', 'pageHits'], (e, {listPosts, postRecords, pageHits}) => {
        updatePostKeys(listPosts, postRecords, pageHits)
      })
    })
    const slashReplacement = '-'

    mainSection.appendChild(domNode({
      tagName: 'div',
      id: 'new-post-container',
      children: [
        {
          tagName: 'button',
          id: 'new-post-button',
          onClick: () => {
            document.getElementById('new-post').classList.toggle('expanded')
            const icon = document.getElementById('new-post-icon')
            const rotation = 'rotate(45, 50, 50)'
            if (icon.getAttribute('transform') === rotation) {
              icon.setAttribute('transform', '')
            } else {
              icon.setAttribute('transform', rotation)
              document.getElementById('new-post').focus()
            }
          },
          children: [
            {
              tagName: 'svg',
              width: '2.5em',
              height: '2.5em',
              viewBox: '0 0 100 100',
              children: [
                {
                  tagName: 'g',
                  id: 'new-post-icon',
                  children: [
                    {
                      tagName: 'line',
                      x1: 15,
                      y1: 50,
                      x2: 85,
                      y2: 50,
                      strokeWidth: '5px',
                      stroke: '#000',
                      strokeLinecap: 'round',
                      strokeLinejoin: 'round',
                    },
                    {
                      tagName: 'line',
                      y1: 15,
                      x1: 50,
                      y2: 85,
                      x2: 50,
                      strokeWidth: '5px',
                      stroke: '#000',
                      strokeLinecap: 'round',
                      strokeLinejoin: 'round',
                    },
                  ]
                }
              ]
            },
          ]
        },
        {
          tagName: 'input',
          type: 'text',
          id: 'new-post',
          classNames: ['new-post'],
          placeholder: I18N_CONFIG.postMetadata.placeholders.id,
          onKeyDown: (evt) => {
            if (evt.which === 13 && evt.target.value) {
              window.location.href = `./edit.html?postId=${evt.target.value.replace(/\//g, slashReplacement)}`
            }
          }
        },
      ]
    }))
    mainSection.appendChild(domNode(
      {
        tagName: 'div',
        id: 'post-list-header',
        children: [
          {
            tagName: 'div',
            classNames: 'post-status-headers',
            children: [
              {
                tagName: 'div',
                classNames: 'post-id-header',
                children: ["Post ID"]
              },
              {
                tagName: 'div',
                classNames: 'save-status-header',
                children: ["Create Date"]
              },
              {
                tagName: 'div',
                classNames: 'publish-status-header',
                children: ["Page Views"]
              },
            ]
          },
          {
            tagName: 'div',
            classNames: 'post-actions-header',
          },
        ]
      }
    ))
    mainSection.appendChild(domNode({
      tagName: 'div',
      id: 'post-list'
    }))
    function postKeyToId(k) {
      const postIdParts = k.split('/').pop().split('.')
      postIdParts.pop()
      const postId = postIdParts.join('.')
      return postId
    }
    function updatePostKeys(listPosts, postRecords, pageHits) {
      let postKeys = _.map(listPosts, 'Key')
      postRecords = _.sortBy(postRecords.postRecords, 'frontMatter.createDate')
      const pageHitsMap = _.reduce(pageHits.pageHits, (acc, v, k) => {
        acc[publicPathToPostId(v.metricId)] = v.hits
        return acc
      }, {})
      console.log(pageHitsMap)
      postKeys = _.reverse(_.sortBy(
        postKeys,
        (k) => _.findIndex(postRecords, (rec) => postKeyToId(k) === rec.id)
      ))
      document.getElementById('post-list').replaceChildren(..._.map(postKeys, (Key) => {
        const postIdParts = Key.split('/').pop().split('.')
        postIdParts.pop()
        const postId = postIdParts.join('.')
        let saveState = getPostSaveState(postId)
        let publishState = getPostPublishState(postId)
        const record = _.find(postRecords, (rec) => postId === rec.id)
        const saved = _.find(listPosts, ({Key}) => postKeyToId(Key) === postId)
        return domNode({
          tagName: 'div',
          classNames: 'post-list-entry',
          children: [
            {
              tagName: 'div',
              id: 'post-running-material',
              children: [
                {
                  tagName: 'div',
                  classNames: 'post-status',
                  children: [
                    {
                      tagName: 'div',
                      classNames: 'post-id',
                      children: [postId]
                    },
                    {
                      tagName: 'div',
                      classNames: 'save-status',
                      children: record ? [new Date(record.frontMatter.createDate).toLocaleString()] : []
                    },
                    {
                      tagName: 'div',
                      classNames: 'publish-status',
                      children: [`${pageHitsMap[postId] || 0}`]
                    },
                  ]
                },
              ]
            },
            {
              tagName: 'div',
              classNames: 'post-actions',
              children: [
                {
                  tagName: 'button',
                  name: 'edit',
                  classNames: 'edit',
                  innerText: I18N_CONFIG.postActions.edit,
                  onClick: () => {
                      window.location.href = `./edit.html?postId=${postId}`
                  }
                },
                {
                  tagName: 'button',
                  name: 'publish',
                  classNames: 'publish',
                  spin: true,
                  innerText: I18N_CONFIG.postActions.publish,
                  onClick: function(evt, stopSpin) {
                    evt.stopPropagation()
                    goph.report(['saveAndPublishPostWithoutInput', 'confirmPostPublished'], {postId}, (e, r) => {
                      if (e) {
                        console.log(e)
                        return
                      }
                      const changedETag = _.get(r, 'saveAndPublishPostWithoutInput[0].ETag')
                      if (changedETag) {
                        setPostPublishState(postId, {etag: changedETag, label: I18N_CONFIG.publishState.mostRecent})
                        setPostSaveState(postId, {etag: changedETag, label: I18N_CONFIG.saveState.unmodified})
                      }
                      evt.target.closest('.post-list-entry').querySelector('.save-status').innerText = I18N_CONFIG.saveState.unmodified
                      evt.target.closest('.post-list-entry').querySelector('.publish-status').innerText = I18N_CONFIG.publishState.mostRecent
                      stopSpin()
                    })
                  }
                },
                {
                  tagName: 'button',
                  name: 'unpublish',
                  classNames: 'unpublish',
                  spin: true,
                  innerText: I18N_CONFIG.postActions.unpublish,
                  onClick: function(evt, stopSpin) {
                    evt.stopPropagation()
                    goph.report(['unpublishPostWithoutInput', 'confirmPostUnpublished'], {postId}, (e, r) => {
                      if (e) {
                        console.log(e)
                        return
                      }
                      const changedETag = _.get(r, 'unPublishPostWithoutInput[0].ETag')
                      if (changedETag) {
                        setPostPublishState(postId, {etag: changedETag, label: I18N_CONFIG.publishState.mostRecent})
                        setPostSaveState(postId, {etag: changedETag, label: I18N_CONFIG.saveState.unmodified})
                      }
                      evt.target.closest('.post-list-entry').querySelector('.save-status').innerText = I18N_CONFIG.saveState.unmodified
                      evt.target.closest('.post-list-entry').querySelector('.publish-status').innerText = I18N_CONFIG.publishState.unpublished
                      stopSpin()
                    })
                  },
                },
                {
                  tagName: 'button',
                  name: 'delete',
                  classNames: 'delete',
                  spin: true,
                  dataset: {
                    postId
                  },
                  innerText: I18N_CONFIG.postActions.delete,
                  onClick: function(evt, stopSpin) {
                    evt.stopPropagation()
                    goph.report(['deletePostWithoutInput', 'confirmPostDeleted'], {postId}, (e, r) => {
                      if (e) {
                        console.log(e)
                        return
                      }
                      const entry = evt.target.closest('.post-list-entry')
                      if (entry && !e) {
                        entry.remove()
                      }
                      deleteLocalState(postId)
                      stopSpin()
                    })
                  },
                },
              ]
            },
          ]
        })
      }))
    }
    updatePostKeys(listPosts, postRecords, pageHits)
  },
  params: {
    listPosts: {
      source: 'listPosts',
      formatter: ({listPosts}) => {
        return listPosts
      }
    },
    postRecords: {
      source: 'postRecords',
    },
    pageHits: {
      source: 'pageHits',
    },
  },
  onAPIError: (e, r, cb) => {
    console.error(e)
    if (_.isString(_.get(e, 'message')) && e.message.indexOf('401') !== -1) {
      location.reload()
    }
    return cb(e, r)
  },
}
