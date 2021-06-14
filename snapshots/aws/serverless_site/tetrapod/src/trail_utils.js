const _ = require('lodash')
const yaml = require('js-yaml')
const hljs = require('highlight.js');
const urlTemplate = require('url-template')
const fs = require('fs')
const TRAIL_TEMPLATE = compileTemplate(fs.readFileSync('./templates/trail.tmpl').toString('utf8'))
const POST_TEMPLATE = compileTemplate(fs.readFileSync('./templates/post.tmpl').toString('utf8'))

const POST_URI_TEMPLATES = {
  md: urlTemplate.parse("https://{domainName}/posts/{name}.md"),
  html: urlTemplate.parse("https://{domainName}/posts/{name}.html")
}

const TRAIL_URI_TEMPLATES = {
  html: urlTemplate.parse("https://{domainName}/trails/{name}.html"),
}

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
  const sortedPostList = _.sortBy(postList, 'frontMatter.createDate')
  const index = _.findIndex(sortedPostList, ({id}) => id === postId)
  return {
    previous: sortedPostList[index - 1],
    next: sortedPostList[index + 1],
  }
}

function getTrailMembers(trailId, postList) {
  return _(postList).sortBy('frontMatter.createDate').filter(post => (_.get(post, 'frontMatter.meta.trails') || []).indexOf(trailId) !== -1).value()
}

function hashTrailsAndPosts(postList) {
  const sortedPostList = _.sortBy(postList, 'frontMatter.createDate')
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
      acc[post.id] = postHash(post) + '.' +  trailHash(post) + '.prev:' + postHash(sortedPostList[indx - 1])  + '.next:' + postHash(sortedPostList[indx + 1])
      return acc
    }, {})
  }
  return ret
}

function findChanges(aList, bList) {
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
      posts: _.uniq(changedPosts)
    },
    deleted: {
      trails: deletedTrails
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
  return _.map(postList, (post) => {
  const postCopy = _.cloneDeep(post)
  postCopy.synthetic = {}
  postCopy.synthetic.url = POST_URI_TEMPLATES.html.expand({domainName, name: post.id})
  postCopy.synthetic.trails = _.map(_.get(postCopy, 'frontMatter.meta.trails'), (trailId) => TRAIL_URI_TEMPLATES.html.expand({domainName, name: trailId}))
  return postCopy
  })
}

// expects annotated post
function renderPostToHTML({runningMaterial, post, neighbors}) {
  return POST_TEMPLATE({runningMaterial, post, neighbors})
}

function renderTrailToHTML({trailId, runningMaterial, members}) {
  return TRAIL_TEMPLATE({trailId, runningMaterial,members})
}

function compileTemplate(s) {
  return _.template(s, {imports: {formatDate: (n) => n.toLocaleString()}})
}

module.exports = {
  postHash,
  parsePost,
  annotatePostList,
  hashTrailsAndPosts,
  findChanges,
  renderTrailToHTML,
  renderPostToHTML,
  compileTemplate,
  getPostNeighbors,
  getTrailMembers,
}
