const _ = require('lodash')
const yaml = require('js-yaml')
const hljs = require('highlight.js');
const urlTemplate = require('url-template')
const fs = require('fs')

const POST_URI_TEMPLATES = {
  md: urlTemplate.parse("https://{domainName}/posts/{name}.md"),
  html: urlTemplate.parse("https://{domainName}/posts/{name}.html")
}

const TRAIL_URI_TEMPLATES = {
  html: urlTemplate.parse("https://{domainName}/trails/{name}.html"),
}

const INDEX_HTML_KEY = 'index.html'

const mdr = require('markdown-it')({
  html: true,
  highlight: function (str, lang) {
    if (lang && hljs.getLanguage(lang)) {
      try {
        return hljs.highlight(lang, str).value;
      } catch (__) {}
    }
    return ''; // use external default escaping
  }
}).use(require('markdown-it-footnote'))

// Basically verbatim from https://github.com/markdown-it/markdown-it/blob/master/docs/architecture.md#renderer , 
// via https://github.com/markdown-it/markdown-it/issues/140
// Remember old renderer, if overridden, or proxy to default renderer
const defaultLinkRender = mdr.renderer.rules.link_open || function(tokens, idx, options, env, self) {
  return self.renderToken(tokens, idx, options);
};

mdr.renderer.rules.link_open = function (tokens, idx, options, env, self) {
  // If you are sure other plugins can't add `target` - drop check below
  var aIndex = tokens[idx].attrIndex('target');

  if (aIndex < 0) {
    tokens[idx].attrPush(['target', '_blank']); // add new attribute
  } else {
    tokens[idx].attrs[aIndex][1] = '_blank';    // replace value of existing attr
  }

  // pass token to default renderer.
  return defaultLinkRender(tokens, idx, options, env, self);
};

function getPostIdFromKey({key}) {
  const postIdParts = key.split('/').pop().split('.')
  postIdParts.pop()
  return postIdParts.join('.')
}

function postHash(postOrNull) {
  if (!postOrNull) {
    return
  }
  return postOrNull.id + '.' + _.get(postOrNull, 'frontMatter.title')
}

function trailHash(postOrNull) {
  const trails = _.get(postOrNull, 'frontMatter.meta.trails')
  if (!_.isArray(trails)) {
    return
  }
  return trails.join(',')
}

function getPostNeighbors(postId, postList) {
  const sortedPostList = sortPostList(postList)
  const index = _.findIndex(sortedPostList, ({id}) => id === postId)
  return {
    previous: sortedPostList[index - 1],
    next: sortedPostList[index + 1],
  }
}

function getTrailMembers(trailId, postList) {
  return _(sortPostList(postList)).filter(post => (_.get(post, 'frontMatter.meta.trails') || []).indexOf(trailId) !== -1).value()
}

function sortPostList(postList) {
  return _.sortBy(postList, (p) => {
    const d = _.get(p, 'frontMatter.createDate')
    return _.isDate(d) ? d.toISOString() : d
  })
}

function hashTrailsAndPosts(postList) {
  const sortedPostList = sortPostList(postList)
  const trailNames = _(postList).map('frontMatter.meta.trails').filter().flatten().uniq().value()
  const ret = {
    trails: _.reduce(trailNames, (acc, name) => {
      acc[name] = _(sortedPostList).filter((i) => _.indexOf(_.get(i, 'frontMatter.meta.trails'), name) !== -1).reduce((acc, post) => {
        acc +=  postHash(post) + '.'
        return acc
      }, '')
      return acc
    }, {}),
    posts: _.reduce(sortedPostList, (acc, post, indx) => {
      const neighbors = getPostNeighbors(post.id, sortedPostList)
      acc[post.id] = postHash(post) + '.' +  trailHash(post) + '.prev:' + postHash(neighbors.previous)  + '.next:' + postHash(neighbors.next)
      return acc
    }, {})
  }
  return ret
}

function findChanges(aList, bList, postId, isDelete) {
  const {trails: atrails, posts: aposts} = hashTrailsAndPosts(aList)
  const {trails: btrails, posts: bposts} = hashTrailsAndPosts(bList)
  const changedTrails = []
  const deletedTrails = []
  const changedPosts = []
  _.each(atrails, (v, k) => {
    if (btrails[k] !== v) {
      if (btrails[k]) {
        changedTrails.push(k)
      } else {
        deletedTrails.push(k)
      }
    }
  })
  _.each(btrails, (v, k) => {
    if (atrails[k] !== v) {
      changedTrails.push(k)
    }
  })
  _.each(aposts, (v, k) => {
    if (bposts[k] !== v) {
      changedPosts.push(k)
    }
  })
  _.each(bposts, (v, k) => {
    if (aposts[k] !== v) {
      changedPosts.push(k)
    }
  })
  return {
    changed: {
      trails: _.uniq(changedTrails),
      posts: _(changedPosts).uniq().filter((x) => x !== postId).value(),
    },
    deleted: {
      trails: deletedTrails,
      posts: isDelete ? [postId] : []
    }
  }
}

function parsePost(postId, s, domainName) {
  if (_.isBuffer(s)) {
    s = s.toString('utf8')
  }
  const t = s.split('\n')
  let started = false
  let frontMatter = ''
  let content = ''
  for (let r of t.slice(1)) {
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
  const fm = yaml.load(frontMatter)
  if (fm.meta.trail) {
    fm.meta.trails = _.union(fm.meta.trail, fm.meta.trails)
    delete fm.meta.trail
  }
  return annotatePost(postId, { frontMatter: fm, content, raw:s }, domainName)
}

function annotatePost(postId, post, domainName) {
  const postCopy = _.cloneDeep(post)
  const rawContent = _.get(post, 'content')
  postCopy.id = postId
  postCopy.synthetic = {}
  postCopy.synthetic.renderedContent = rawContent ? mdr.render(rawContent) : undefined
  postCopy.synthetic.url = POST_URI_TEMPLATES.html.expand({domainName, name: postId})
  postCopy.synthetic.trails = _.map(_.get(postCopy, 'frontMatter.meta.trails'), (trailId) => TRAIL_URI_TEMPLATES.html.expand({domainName, name: trailId}))
  return postCopy
}

function annotatePostList(postList, domainName) {
  return sortPostList(_.map(postList, (post) => {
    const postCopy = _.cloneDeep(post)
    postCopy.synthetic = {}
    postCopy.synthetic.url = POST_URI_TEMPLATES.html.expand({domainName, name: post.id})
    postCopy.synthetic.trails = _.map(_.get(postCopy, 'frontMatter.meta.trails'), (trailId) => TRAIL_URI_TEMPLATES.html.expand({domainName, name: trailId}))
    return postCopy
  }))
}

// expects annotated post
function renderPostToHTML({runningMaterial, post, neighbors, postTemplate}) {
  return compileTemplate(postTemplate)({runningMaterial, post, neighbors})
}

function renderTrailToHTML({trailId, runningMaterial, members, trailTemplate}) {
  return compileTemplate(trailTemplate)({trailId, runningMaterial,members})
}

function compileTemplate(s) {
  return _.template(_.isBuffer(s) ? s.toString('utf8') : s, {imports: {formatDate: (n) => n.toLocaleString()}})
}

function isS3Delete({eventType}) {
  return _.startsWith(eventType, 'ObjectRemoved')
}

function trailHTMLKey(trailId) {
  return `trails/${trailId}.html`
}

function postHTMLKey(postId) {
  return `posts/${postId}.html`
}

function postMDKey(postId) {
  return `posts/${postId}.md`
}

function renderChangedPosts({posts, runningMaterial, currentPostList, postTemplate}) {
  const annotatedPostList = annotatePostList(_.cloneDeep(currentPostList), runningMaterial.domainName)
  return _.map(posts, ({text, id}) => {
    const parsed = parsePost(id, text, runningMaterial.domainName)
    const neighbors = getPostNeighbors(id, annotatedPostList)
    return {
      key: postHTMLKey(id),
      rendered: renderPostToHTML({runningMaterial, post: parsed, neighbors, postTemplate})
    }
  })
}

function postRecordToDynamoDeleteKey(pr) {
  return {kind: 'post', id: pr.id}
}

function postRecordToDynamo(pr) {
  return {kind: 'post', id: pr.id, frontMatter: pr.frontMatter}
}

function determineUpdates({postText, previousPostList, isDelete, postId, runningMaterial, postTemplate, trailTemplate}) {
  const annotatedPreviousPostList = annotatePostList(_.cloneDeep(previousPostList), runningMaterial.domainName)
  const parsedPost = isDelete ? null : parsePost(postId, postText, runningMaterial.domainName)
  let newPostList = _.cloneDeep(annotatedPreviousPostList)
  const dynamoDeletes = []
  const dynamoPuts = []
  const currentPostRecord = _.find(newPostList, (p) => p.id === postId)
  if (isDelete) {
    newPostList = newPostList.filter((p) => p.id !== postId)
    if (currentPostRecord) {
      dynamoDeletes.push(postRecordToDynamoDeleteKey(currentPostRecord))
    }
  } else if (!currentPostRecord) {
    newPostList.push({
      id: postId,
      frontMatter: _.cloneDeep(parsedPost.frontMatter),
      synthetic: _.cloneDeep(parsedPost.synthetic),
    })
    dynamoPuts.push(postRecordToDynamo(parsedPost))
  } else {
    currentPostRecord.frontMatter = _.cloneDeep(parsedPost.frontMatter)
    dynamoPuts.push(postRecordToDynamo(parsedPost))
  }
  const diffs = findChanges(annotatedPreviousPostList, newPostList, postId, isDelete)
  const neighbors = isDelete ? null : getPostNeighbors(postId, newPostList)
  const renderedPost = isDelete ? null : {
    key: postHTMLKey(postId),
    rendered: renderPostToHTML({runningMaterial, post: parsedPost, neighbors,  postTemplate})
  }
  const trailUpdates = _.map(diffs.changed.trails, (trailId) => {
    return {
      key: trailHTMLKey(trailId),
      rendered: renderTrailToHTML({trailId, runningMaterial, members: getTrailMembers(trailId, newPostList), trailTemplate})
    }
  })
  const indexContent = renderTrailToHTML({trailId: 'posts', runningMaterial, members: newPostList, trailTemplate})
  trailUpdates.push({
    key: trailHTMLKey('posts'),
    rendered: indexContent,
  })
  trailUpdates.push({
    key: INDEX_HTML_KEY,
    rendered: indexContent,
  })
  const trailDeleteKeys = _.map(diffs.deleted.trails, trailHTMLKey)
  const postUpdateKeys = _.map(diffs.changed.posts, postMDKey)
  const postDeleteKeys = isDelete ? [postHTMLKey(postId)] : []
  return {
    dynamoPuts,
    dynamoDeletes,
    parsedPost,
    newPostList,
    diffs,
    neighbors,
    trailUpdates,
    renderedPost,
    trailDeleteKeys,
    postUpdateKeys,
    postDeleteKeys,
  }
}

module.exports = {
  postHash,
  getPostIdFromKey,
  parsePost,
  annotatePostList,
  hashTrailsAndPosts,
  findChanges,
  renderTrailToHTML,
  renderPostToHTML,
  compileTemplate,
  getPostNeighbors,
  getTrailMembers,
  isS3Delete,
  renderChangedPosts,
  determineUpdates,
}
