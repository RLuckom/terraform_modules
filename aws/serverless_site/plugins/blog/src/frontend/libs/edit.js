window.RENDER_CONFIG = {
  init: ({post, publishedETag}, gopher) => {
    window.goph = gopher
    const postId = new URLSearchParams(window.location.search).get('postId').replace(/\//g, '-') + window.location.hash
    let publishedState = getPostPublishState(postId)
    if (publishedETag && publishedETag !== _.get(publishedState, 'etag')) {
      if (publishedETag === _.get(post, 'etag')) {
        publishedState = setPostPublishState(postId, {etag: publishedETag, label: I18N_CONFIG.publishState.mostRecent})
      } else {
        publishedState = setPostPublishState(postId, {etag: publishedETag, label: I18N_CONFIG.publishState.modified})
      }
    } else if (!publishedETag) {
        publishedState = setPostPublishState(postId, {etag: null, label: I18N_CONFIG.publishState.unpublished})
    } 
    let saveState = getPostSaveState(postId)
    let editorState = getPostEditorState(postId)
    if (!editorState || _.get(editorState, 'etag') !== _.get(post, 'etag')) {
      if (!post) {
        editorState = setPostEditorState(postId, {
          title: postId,
          trails: [],
          content: '',
          imageIds: [],
          footnotes: {},
        })
        saveState = setPostSaveState(postId, {etag: null, label: I18N_CONFIG.saveState.unsaved})
      } else {
        editorState = setPostEditorState(postId, {
          title: post.frontMatter.title || postId,
          trails: post.frontMatter.meta.trails || post.frontMatter.meta.trail,
          content: post.content,
          imageIds: post.frontMatter.meta.imageIds,
          etag: post.etag,
          footnotes: _.get(post, 'footnotes', {}),
        })
        saveState = setPostSaveState(postId, {etag: post.etag, label: I18N_CONFIG.saveState.unmodified})
      }
    }
    const mainSection = document.querySelector('main')
    function mergeEditorStateToPost() {
      return latestKnownPostState(postId)
    }

    function setSaveState(text) {
      document.getElementById('save-status').innerText = text
    }
    function setPublishState(text) {
      document.getElementById('publish-status').innerText = text
    }
    mainSection.append(...domNodes(
      {
        tagName: 'div',
        id: 'info-toolbar',
        children: [
          {
            tagName: 'div',
            classNames: 'post-info',
            children: [
              {
                tagName: 'div',
                classNames: 'to-index',
                children: [
                  {
                    tagName: 'a',
                    href: './index.html',
                    children: [
                      {
                        tagName: 'svg',
                        width: '1em',
                        height: '2em',
                        viewBox: '0 0 50 100',
                        children: [
                          {
                            tagName: 'polyline',
                            points: [{
                              y: 10,
                              x: 40,
                            },
                            {
                              y: 50,
                              x: 10,
                            }, 
                            {
                              y: 90,
                              x: 40,
                            },
                            ],
                            strokeWidth: '0.4em',
                            stroke: '#000',
                            strokeLinecap: 'round',
                            strokeLinejoin: 'round',
                            fill: 'transparent',
                          }
                        ]
                      }
                    ]
                  },
                ]
              },
              {
                tagName: 'div',
                id: 'post-id',
                classNames: 'post-id edit',
                children: [{
                  tagName: 'span',
                  classNames: 'title-post-id',
                  children: [postId],
                }]
              },
              {
                tagName: 'div',
                id: 'post-running-material',
                classNames: 'edit',
                children: [
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
                            classNames: 'save-status-header',
                            children: ["Create Date"]
                          },
                          {
                            tagName: 'div',
                            classNames: 'publish-status-header',
                            children: ["Last Saved"]
                          },
                        ]
                      },
                    ]
                  },
                  {
                    tagName: 'div',
                    classNames: 'post-status edit',
                    children: [
                      {
                        tagName: 'div',
                        id: 'save-status',
                        classNames: 'save-status',
                      },
                      {
                        tagName: 'div',
                        id: 'publish-status',
                        classNames: 'publish-status',
                      },
                    ]
                  },
                ]
              },
            ]
          },
        ]
      },
      {
        tagName: 'div',
        classNames: 'authoring-inputs',
        children: [
          {
            tagName: 'input',
            type: 'text',
            name: 'title',
            classNames: 'authoring-input',
            placeholder: I18N_CONFIG.postMetadata.placeholders.title,
            value: editorState.title,
            id: 'title',
            onChange: (e) => updateEditorState(postId, {title: e.target.value}, updateFootnoteMenu)
          },
          {
            tagName: 'div',
            id: 'post-editor',
            classNames: ['prosemirror', 'editor'],
          },
          {
            tagName: 'div',
            id: 'post-footnotes',
          },
          {
            tagName: 'div',
            id: 'post-actions',
            children: [
              {
                tagName: 'div',
                classNames: 'button-container',
                children: [
                  {
                    tagName: 'button',
                    name: 'save',
                    classNames: 'save',
                    spin: true,
                    innerText: I18N_CONFIG.postActions.save,
                    onClick: function(evt, stopSpin) {
                      evt.stopPropagation()
                      const postToSave = mergeEditorStateToPost()
                      goph.report('savePostWithoutPublishing', {post: postToSave, postId}, (e, r) => {
                        const changedETag = _.get(r, 'savePostWithoutPublishing[0].ETag')
                        if (changedETag) {
                          postToSave.etag = changedETag
                          updateEditorState(postId, {etag: changedETag}, updateFootnoteMenu)
                          setPostAsSaved(postId, postToSave)
                          setPostSaveState(postId, {etag: changedETag, label: I18N_CONFIG.saveState.unmodified})
                        }
                        if (postToSave.etag !== getPostPublishState.etag) {
                          updatePostPublishState(postId, {label: I18N_CONFIG.publishState.modified})
                          const changedDate = new Date()
                          setPublishState(changedDate.toLocaleString())
                        }
                        stopSpin()
                      })
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
                      const postToSave = mergeEditorStateToPost()
                      goph.report(['saveAndPublishPost', 'confirmPostPublished'], {post: postToSave, postId}, (e, r) => {
                        if (e) {
                          console.error(e)
                          return
                        }
                        const changedETag = _.get(r, 'saveAndPublishPost[0].ETag')
                        if (changedETag) {
                          postToSave.etag = changedETag
                          updateEditorState(postId, {etag: changedETag}, updateFootnoteMenu)
                          setPostAsSaved(postId, postToSave)
                          setPostPublishState(postId, {etag: changedETag, label: I18N_CONFIG.publishState.mostRecent})
                          setPostSaveState(postId, {etag: changedETag, label: I18N_CONFIG.saveState.unmodified})
                        }
                        const changedDate = new Date()
                        setPublishState(changedDate.toLocaleString())
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
                      const postToSave = mergeEditorStateToPost()
                      goph.report(['unpublishPost', 'confirmPostUnpublished'], {post: postToSave, postId}, (e, r) => {
                        if (e) {
                          console.error(e)
                          return
                        }
                        const changedETag = _.get(r, 'unpublishPost[0].ETag')
                        if (changedETag) {
                          postToSave.etag = changedETag
                          updateEditorState(postId, {etag: changedETag}, updateFootnoteMenu)
                          setPostAsSaved(postId, postToSave)
                          setPostPublishState(postId, {etag: null, label: I18N_CONFIG.publishState.unpublished})
                        }
                        const changedDate = new Date() 
                        setPublishState(changedDate.toLocaleString())
                        stopSpin()
                      })
                    },
                  }
                ]
              },
            ]
          },
          {
            tagName: 'div',
            id: 'error',
          }
        ]
      }))
      if (_.isDate(_.get(post, 'frontMatter.createDate'))) {
        setSaveState(post.frontMatter.createDate.toLocaleString())
      } else if (_.isString(_.get(post, 'frontMatter.createDate'))) {
        setSaveState(new Date(post.frontMatter.createDate).toLocaleString())
      }
      if (_.isDate(_.get(post, 'lastSaved'))) {
        setPublishState(post.lastSaved.toLocaleString())
      }

      function uploadImage(buffer, ext, callback) {
        const imageId = uuid.v4()
        const canonicalExt = canonicalImageTypes[_.toLower(ext)]
        const privateImageUrl = getImagePrivateUrl({postId, imageId, ext: canonicalExt, size: 500})
        goph.report(
          'pollImage',
          {
            imageExt: canonicalExt,
            postId: postId,
            imageId: imageId,
            imageSize: 500,
            buffer,
          },
          (e, r) => {
            callback(e, {
              url: privateImageUrl,
              imageId
            })
          }
        )
      }

      function addFootnote() {
        const latestEditorState = getPostEditorState(postId)
        const footnoteNumber = _.keys(latestEditorState.footnotes || {}).length + 1
        document.getElementById('post-footnotes').appendChild(buildFootnoteEditor(postId, footnoteNumber, uploadImage, updateFootnoteMenu))
      }

      const postContentForProsemirror = prepareEditorString(editorState.content, postId)
      const {updateFootnoteMenu} = prosemirrorView({
        container: document.getElementById('post-editor'),
        uploadImage, 
        onChange: _.partialRight(_.partial(updateEditorState, postId)),
        initialState: editorState.editorState,
        initialMarkdownText: postContentForProsemirror,
        footnotes: editorState.footnotes || {},
        addFootnote,
        postId
      })
      const latestEditorState = getPostEditorState(postId)
      _.each(latestEditorState.footnotes, (v, k) => {
        document.getElementById('post-footnotes').appendChild(buildFootnoteEditor(postId, k, uploadImage, updateFootnoteMenu))
      })
  },
  params: {
    post: {
      source: 'getPost',
      formatter: ({getPost}) => {
        return getPost
      }
    },
    publishedETag: {
      source: 'getPublishedPostETag',
      formatter: ({getPublishedPostETag}) => {
        return getPublishedPostETag
      }
    },
  },
  inputs: {
    postId: new URLSearchParams(window.location.search).get('postId').replace(/\//g, '-'),
  },
  onAPIError: (e, r, cb) => {
    console.error(e)
    if (_.isString(_.get(e, 'message')) && e.message.indexOf('401') !== -1) {
      location.reload()
    }
    return cb(e, r)
  }
}
