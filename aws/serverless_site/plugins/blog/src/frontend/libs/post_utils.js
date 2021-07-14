// Adapted from https://github.com/markdown-it/markdown-it-footnote/blob/master/index.js
function footnote_plugin(md, {parse_defs}) {
  function footnote_def(state, startLine, endLine, silent) {
    var oldBMark, oldTShift, oldSCount, oldParentType, pos, label, token,
    initial, offset, ch, posAfterColon,
    start = state.bMarks[startLine] + state.tShift[startLine],
      max = state.eMarks[startLine];
    const originalStart = start

    // line should be at least 5 chars - "[^x]:"
    if (start + 4 > max) { return false; }

    if (state.src.charCodeAt(start) !== 0x5B/* [ */) { return false; }
    if (state.src.charCodeAt(start + 1) !== 0x5E/* ^ */) { return false; }

    for (pos = start + 2; pos < max; pos++) {
      if (state.src.charCodeAt(pos) === 0x20) { return false; }
      if (state.src.charCodeAt(pos) === 0x5D /* ] */) {
        break;
      }
    }

    if (pos === start + 2) { return false; } // no empty footnote labels
    if (pos + 1 >= max || state.src.charCodeAt(++pos) !== 0x3A /* : */) { return false; }
    if (silent) { return true; }
    pos++;

    if (!state.env.footnotes) { state.env.footnotes = {}; }
    label = state.src.slice(start + 2, pos - 2);

    token       = new state.Token('footnote_reference_open', '', 1);
    token.meta  = { label: label };
    token.level = state.level++;
    state.tokens.push(token);

    oldBMark = state.bMarks[startLine];
    oldTShift = state.tShift[startLine];
    oldSCount = state.sCount[startLine];
    oldParentType = state.parentType;

    posAfterColon = pos;
    initial = offset = state.sCount[startLine] + pos - (state.bMarks[startLine] + state.tShift[startLine]);

    while (pos < max) {
      ch = state.src.charCodeAt(pos);

      if (md.utils.isSpace(ch)) {
        if (ch === 0x09) {
          offset += 4 - offset % 4;
        } else {
          offset++;
        }
      } else {
        break;
      }

      pos++;
    }

    state.tShift[startLine] = pos - posAfterColon;
    state.sCount[startLine] = offset - initial;

    state.bMarks[startLine] = posAfterColon;
    state.blkIndent += 4;
    state.parentType = 'footnote';

    if (state.sCount[startLine] < state.blkIndent) {
      state.sCount[startLine] += state.blkIndent;
    }

    state.md.block.tokenize(state, startLine, endLine, true);
    const content = state.getLines(startLine, state.line, state.blkIndent, false).trim();
    state.env.footnotes[label] = content
    if (!state.env.footnoteStartPos) {
      state.env.footnoteStartPos = originalStart
    }

    state.parentType = oldParentType;
    state.blkIndent -= 4;
    state.tShift[startLine] = oldTShift;
    state.sCount[startLine] = oldSCount;
    state.bMarks[startLine] = oldBMark;

    token       = new state.Token('footnote_reference_close', '', -1);
    token.level = --state.level;
    state.tokens.push(token);

    return true;
  }

  // Process footnote references ([^...])
  function footnote_ref(state, silent) {
    var label,
    pos,
    footnoteId,
    footnoteSubId,
    token,
    max = state.posMax,
      start = state.pos;

    // should be at least 4 chars - "[^x]"
    if (start + 3 > max) { return false; }

    if (state.src.charCodeAt(start) !== 0x5B/* [ */) { return false; }
    if (state.src.charCodeAt(start + 1) !== 0x5E/* ^ */) { return false; }

    for (pos = start + 2; pos < max; pos++) {
      if (state.src.charCodeAt(pos) === 0x20) { return false; }
      if (state.src.charCodeAt(pos) === 0x0A) { return false; }
      if (state.src.charCodeAt(pos) === 0x5D /* ] */) {
        break;
      }
    }

    if (pos === start + 2) { return false; } // no empty footnote labels
    if (pos >= max) { return false; }
    pos++;

    label = state.src.slice(start + 2, pos - 1);


    token      = state.push('footnote_ref', '', 0);
    token.meta = { id: label, ref: label, subId: label, label: label };

    state.pos = pos;
    state.posMax = max;
    return true;
  }
  md.inline.ruler.after('image', 'footnote_ref', footnote_ref);
  if (parse_defs) {
    md.block.ruler.before('reference', 'footnote_def', footnote_def, { alt: [ 'paragraph', 'reference' ] });
  }
}

function getPostUploadKey({postId}) {
  return `${CONFIG.plugin_post_upload_path}${postId}.md`
}

function getPostHostingKey({postId}) {
  return `${CONFIG.plugin_post_hosting_path}${postId}.md`
}

function getPostPublicKey({postId}) {
  return `${CONFIG.blog_post_hosting_prefix}${postId}.md`
}

function getImageUploadKey({postId, imageId, imageExt}) {
  return `${CONFIG.plugin_image_upload_path}${postId}/${imageId}.${imageExt}`
}

function getPostDataKey(postId) {
  return `plugins/${CONFIG.name}/postData?postId=${postId}`
}

function getPostSaveStateDataKey(postId) {
  return `plugins/${CONFIG.name}/postData?postId=${postId}&field=saveState`
}

function getPostAsSavedDataKey(postId) {
  return `plugins/${CONFIG.name}/postData?postId=${postId}&field=asSaved`
}

function getPostPublishStateDataKey(postId) {
  return `plugins/${CONFIG.name}/postData?postId=${postId}&field=publishState`
}

function getPostEditorStateDataKey(postId) {
  return `plugins/${CONFIG.name}/postData?postId=${postId}&field=editorState`
}

function getParsedLocalStorageData(key) {
  if (key.indexOf('[object Object]') !== -1) {
    console.log(new Error('obj in k'))
  }
  const savedData = localStorage.getItem(key)
  if (savedData) {
    const parsed = JSON.parse(savedData)
    return parsed
  }
  return null
}

function updateLocalStorageData(key, updates) {
  const updatedRecord = _.assign({}, getParsedLocalStorageData(key), updates)
  localStorage.setItem(key, JSON.stringify(updatedRecord))
  return updatedRecord
}

function setPostAsSaved(postId, post) {
  const postDataKey = getPostAsSavedDataKey(postId)
  localStorage.setItem(postDataKey, JSON.stringify(post || null))
  return post || null
}

function setPostEditorState(postId, editorState) {
  const postDataKey = getPostEditorStateDataKey(postId)
  localStorage.setItem(postDataKey, JSON.stringify(editorState))
  return editorState
}

function setPostPublishState(postId, state) {
  const postDataKey = getPostPublishStateDataKey(postId)
  localStorage.setItem(postDataKey, JSON.stringify(state))
  return state
}

function setPostSaveState(postId, state) {
  const postDataKey = getPostSaveStateDataKey(postId)
  localStorage.setItem(postDataKey, JSON.stringify(state))
  return state
}

function updatePostAsSaved(postId, post) {
  const postDataKey = getPostAsSavedDataKey(postId)
  return updateLocalStorageData(postDataKey, post)
}

function updatePostEditorState(postId, editorState) {
  const postDataKey = getPostEditorStateDataKey(postId)
  return updateLocalStorageData(postDataKey, editorState)
}

function updatePostPublishState(postId, state) {
  const postDataKey = getPostPublishStateDataKey(postId)
  return updateLocalStorageData(postDataKey, state)
}

function updatePostSaveState(postId, state) {
  const postDataKey = getPostSaveStateDataKey(postId)
  return updateLocalStorageData(postDataKey, state)
}

function getPostAsSaved(postId) {
  const postDataKey = getPostAsSavedDataKey(postId)
  return getParsedLocalStorageData(postDataKey)
}

function getPostEditorState(postId) {
  const postDataKey = getPostEditorStateDataKey(postId)
  return getParsedLocalStorageData(postDataKey)
}

function getPostPublishState(postId) {
  const postDataKey = getPostPublishStateDataKey(postId)
  return getParsedLocalStorageData(postDataKey)
}

function getPostSaveState(postId) {
  const postDataKey = getPostSaveStateDataKey(postId)
  return getParsedLocalStorageData(postDataKey)
}

function deleteLocalState(postId) {
  _.each([
    getPostSaveStateDataKey(postId),
    getPostPublishStateDataKey(postId),
    getPostEditorStateDataKey(postId),
    getPostDataKey(postId),
    getPostAsSavedDataKey(postId),
  ], (k) => {
    localStorage.removeItem(k)
  })
}

const canonicalImageTypes = {
  png: 'png', 
  jpg: 'jpg',
  jpeg: 'jpg',
  tif: 'tif',
  tiff: 'tif',
  webp: 'webp',
  heic: 'heic',
  svg: 'svg',
  gif: 'gif',
}


function getImagePrivateUrl({postId, imageId, size, ext}) {
  const canonicalExt = canonicalImageTypes[_.toLower(ext)]
  if (!canonicalExt) {
    throw new Error("unsupported image type")
  }
  return `https://${CONFIG.domain}/${CONFIG.plugin_image_hosting_path}${encodeURIComponent(postId)}/${imageId}/${size}.${canonicalExt}`
}

function parsePost(s) {
  const t = s.split('\n')
  if (_.trim(t[0]) === '---') {
    let started = false
    let frontMatter = ''
    let content = ''
    let footnotes
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
      const env = {}
      const footnoteMarkdownParser = markdownit("commonmark", {html: false}).use(footnote_plugin, {parse_defs: true}).parse(content, env)
      footnotes = env.footnotes
      if (env.footnoteStartPos) {
        content = content.slice(0, env.footnoteStartPos)
      }
    } catch(e) {
      console.error(e)
    }
    try {
      const fm = yaml.load(frontMatter)
      return { frontMatter: fm, footnotes, content, raw:s }
    } catch(e) {
      console.error(e)
      return { raw: s} 
    }
  } else {
    return { raw: s }
  }
}

function newPost() {
  return {
    frontMatter: {
      title: '',
      author: CONFIG.operator_name,
      meta: {
        trails: [],
        imageIds: [],
      },
    },
    footnotes: {},
    content: '',
    etag: ''
  }
}

/*
 * Gets the most recent post as saved. 
 * if saved doesn't exist, or if there's a pending edit on the same etag as saved,
 * the edit is merged into the state. Else, the most recent save state is returned.
 * So if you edit on device A, then edit and save on device B, device A will throw out
 * your local edits when it detects the new save state.
 */
function latestKnownPostState(postId) {
  const mergedPost = _.cloneDeep(getPostAsSaved(postId) || newPost())
  const editorState = getPostEditorState(postId)
  if (editorState && (!mergedPost.etag || editorState.etag === mergedPost.etag)) {
    mergedPost.frontMatter.meta.imageIds = _.cloneDeep(editorState.imageIds)
    mergedPost.frontMatter.meta.trails = _.cloneDeep(editorState.trails)
    mergedPost.frontMatter.title = _.cloneDeep(editorState.title)
    mergedPost.content = _.cloneDeep(editorState.content)
    mergedPost.footnotes = _.cloneDeep(editorState.footnotes || {})
  }
  mergedPost.footnotes = mergedPost.footnotes || {}
  return mergedPost
}

function serializePostToMarkdown({frontMatter, content, footnotes}) {
  let text = `---\n${yaml.dump(frontMatter)}---\n${_.trimEnd(content)}\n\n`
  _(footnotes).toPairs().sortBy((v) => v[0]).each(([k, v]) => {
    const indent = _.repeat(' ', (`[^${k}]: `).length)
    text += `[^${k}]: ${_.map(v.split('\n'), _.trimStart).join(`\n${indent}`)}\n\n`
  })
  return text
}

const serializePost = serializePostToMarkdown

//
const htmlPostRegex = new RegExp('/posts/([^/]*).html')
function publicPathToPostId(publicPath) {
  // This double-encoded path representation is what the Cloudfront logs produce, saved as-is into dynamo
  // by the metric collector function. We _could_ do this decoding before saving it in dynamo, maybe that's
  // better, I'm still thinking about it. I'm worried that it would be harder to clean up everything mis-saved
  // in dynamo if something like that breaks, than for consumers to caveat emptor.
  return decodeURIComponent(decodeURIComponent(_.get((publicPath || "").match(htmlPostRegex), 1) || ""))
}

function prepareEditorString(s, postId) {
  const postIdInLinkRegex = new RegExp("\\((https:\/\/.*)" + postId + '([^\\)]*)\\)', 'g')
  const postIdInRelativeLinkRegex = new RegExp("]\\(/(.*)" + postId + '([^\\)]*)\\)', 'g')
  return s.replace(postIdInLinkRegex, (match, g1, g2) => "(" + g1 + encodeURIComponent(postId) + g2 + ')').replace(
    postIdInRelativeLinkRegex, (match, g1, g2) => "](/" + g1 + encodeURIComponent(postId) + g2 + ')')
}

function buildFootnoteEditor(postId, footnoteNumber, uploadImage, updateFootnoteMenu) {
  let name = footnoteNumber + ''
  let deleteable = false
  const latestEditorState = getPostEditorState(postId)
  latestEditorState.footnotes = latestEditorState.footnotes || {}
  latestEditorState.footnoteEditorStates = latestEditorState.footnoteEditorStates || {}
  latestEditorState.footnotes[name] = latestEditorState.footnotes[name] || ''
  updateEditorState(postId, {footnotes: latestEditorState.footnotes, footnoteEditorStates: latestEditorState.footnoteEditorStates}, updateFootnoteMenu)

  function onFootnoteNameChange(e) {
    const oldName = name
    if (!e.target.value || e.target.value === name) {
      return
    }
    const latestEditorState = getPostEditorState(postId)
    let testUnique = ''
    while (latestEditorState.footnotes[e.target.value + testUnique]) {
      testUnique = testUnique || 0
      testUnique += 1
    }
    e.target.value += testUnique
    const content = latestEditorState.footnotes[name]
    const editorState = latestEditorState.footnoteEditorStates[name]
    delete latestEditorState.footnotes[name]
    delete latestEditorState.footnoteEditorStates[name]
    name = e.target.value
    latestEditorState.footnotes[name] = content
    latestEditorState.footnoteEditorStates[name] = editorState
    updateEditorState(postId, {footnotes: latestEditorState.footnotes, footnoteEditorStates: latestEditorState.footnoteEditorStates}, updateFootnoteMenu, {[oldName]: e.target.value})
  }

  function onFootnoteDelete(e) {
    const latestEditorState = getPostEditorState(postId)
    delete latestEditorState.footnotes[name]
    delete latestEditorState.footnoteEditorStates[name]
    updateEditorState(postId, {footnotes: latestEditorState.footnotes, footnoteEditorStates: latestEditorState.footnoteEditorStates}, updateFootnoteMenu, {[name]: null})
    editorDiv.remove()
  }

  function onStateChange({editorState, content}) {
    const latestEditorState = getPostEditorState(postId)
    latestEditorState.footnotes[name] = content
    latestEditorState.footnoteEditorStates[name] = editorState
    updateEditorState(postId, {footnotes: latestEditorState.footnotes, footnoteEditorStates: latestEditorState.footnoteEditorStates}, updateFootnoteMenu)
  }
  const editorDiv = domNode({
    tagName: 'div',
    children: [
      {
        tagName: 'div',
        classNames: 'footnote-title-bar',
        children: [
          {
            tagName: 'input',
            type: 'text',
            name: 'footnote name',
            classNames: ['authoring-input', 'footnote-marker'],
            onKeyUp: (evt) => evt.target.value = evt.target.value.replace(/[^A-z0-9]/, ''),
            placeholder: I18N_CONFIG.postMetadata.placeholders.footnoteTitle,
            value: name,
            onChange: onFootnoteNameChange,
          },
          {
            tagName: 'button',
            classNames: 'delete-footnote',
            innerText: I18N_CONFIG.editActions.deleteFootnote,
            onClick: function(evt) {
              if (deleteable) {
                onFootnoteDelete(evt)
                deleteable = false
              } else {
                deleteable = true
                editorDiv.querySelector('.delete-footnote').innerText = I18N_CONFIG.editActions.reallyDeleteFootnote
                setTimeout(function() {
                  if (deleteable) {
                    deleteable = false
                    editorDiv.querySelector('.delete-footnote').innerText = I18N_CONFIG.editActions.deleteFootnote
                  }
                }, 5000)
              }
            }
          },
        ]
      },
      {
        tagName: 'div',
        classNames: ['prosemirror', 'editor'],
      }
    ]
  })
  prosemirrorView({
    container: editorDiv.querySelector('.editor'), 
    uploadImage,
    onChange: onStateChange, 
    initialState: latestEditorState.footnoteEditorStates[name],
    initialMarkdownText: latestEditorState.footnotes[name],
    postId
  })
  return editorDiv
}

function getImageIds({ content, footnotes, postId}) {
  const imageIdsRegex = new RegExp(`https://${CONFIG.domain}/${CONFIG.plugin_image_hosting_path}${encodeURIComponent(postId)}/([0-9a-f-]{36})/`, 'g')
  let imageIds = _.uniq(_.map(_.reduce([content, ..._.values(footnotes)], (acc, v) => {
    return _.concat(acc, _.filter(Array.from((v || '').matchAll(imageIdsRegex)), (x) => _.isString(_.get(x, 1))))
  }, []), (x) => x[1]))
  return imageIds
}

const imageKeyRegexp = new RegExp('https://' + CONFIG.domain + '/' +CONFIG.plugin_image_hosting_path + '([^/]*)/([0-9a-f-]{36})/([0-9]*).(.*)')
function parseImageUrl(url) {
  if (!_.isString(url)) {
    return {
      originalUrl: url
    }
  }
  const parts = url.match(imageKeyRegexp)
  if (!parts) {
    return {
      originalUrl: url
    }
  }
  const [originalUrl, encodedPostId, imageId, size, canonicalExt] = parts
  if (encodedPostId && imageId && size && canonicalExt) {
    return {originalUrl, imageId, postId: decodeURIComponent(encodedPostId), size, canonicalExt}
  }
  return {
    originalUrl
  }
}

function updateEditorState(postId, updates, updateFootnoteMenu, updatedFootnoteNames) {
  const latestEditorState = getPostEditorState(postId)
  let isModified = false
  let imageIds = getImageIds({
    content: updates.content || latestEditorState.content || '',
    footnotes: updates.footnotes || latestEditorState.footnotes || {},
    postId,
  })
  const changedFields = _.reduce(updates, (acc, v, k) => {
    if (!_.isEqual(v, latestEditorState[k])) {
      acc[k] = v
    }
    return acc
  }, {})
  if (!_.isEqual(imageIds, latestEditorState.imageIds)) {
    changedFields.imageIds = imageIds
  } else {
    delete changedFields.imageIds
  }

  const postAsSaved = getPostAsSaved(postId)
  if (updates.title && !_.isEqual(updates.title, _.get(postAsSaved, 'frontMatter.title'))) {
    isModified = true
  }
  if (updatedFootnoteNames) {
    updateFootnoteMenu({names: updatedFootnoteNames})
    isModified = true
  }
  if (!_.isEqual(imageIds, _.get(postAsSaved, 'frontMatter.meta.imageIds'))) {
    isModified = true
  }
  if (updates.trails && !_.isEqual(updates.trails, _.get(postAsSaved, 'frontMatter.meta.trails'))) {
    isModified = true
  }
  if (updates.content && !_.isEqual(updates.content, _.get(postAsSaved, 'content'))) {
    isModified = true
  }
  if (updates.footnotes && !_.isEqual(updates.footnotes, _.get(postAsSaved, 'footnotes'))) {
    updateFootnoteMenu({footnotes: updates.footnotes})
    isModified = true
  }
  const newEditorState = updatePostEditorState(postId, changedFields)
  const s = updatePostSaveState(postId, {label: isModified ? I18N_CONFIG.saveState.modified : I18N_CONFIG.saveState.unmodified})
}
