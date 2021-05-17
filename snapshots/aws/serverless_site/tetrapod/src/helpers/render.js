const _ = require('lodash')
const yaml = require('js-yaml')
const moment = require('moment')
const hljs = require('highlight.js');
const { urlToPath, expandUrlTemplateWithName, identifyUriBuilder } = require('./idUtils')
const { Feed } = require('feed')
const formatters = require('./formatters')

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

//TODO: make this also accept toml, json front matter
function parsePost(s) {
  const t = s.split('\n')
  if (_.trim(t[0]) === '---') {
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
    try {
      const fm = yaml.safeLoad(frontMatter)
      if (fm.date) {
        fm.date = moment(fm.date)
      }
      return { frontMatter: fm, content, raw:s }
    } catch(e) {
      return { raw: s} 
    }
  } else {
    return { raw: s }
  }
}

function renderHTML({siteDetails, item, dependencies, identifyUri}) {
  const rawContent = _.get(dependencies, 'doc.content')
  const content = rawContent ? mdr.render(rawContent) : undefined
  const frontMatter = _.get(dependencies, 'doc.frontMatter') || {}
  return _.template(dependencies.template.toString(), {imports: {identifyUri, formatDate: (n) => moment(n).format("MMM D Y hh:mma")}})({ item: { ...frontMatter,  content }, meta: dependencies.trails, siteDetails})
}

function renderFeed(feedType, {siteDetails, item, dependencies}) {
  const {doc, accumulators} = dependencies
  const feed = new Feed({
    title: `${item.name} ${item.type}`,
    description: item.description || "",
    id: item.formatUrls[feedType].uri,
    link: item.formatUrls['html'].uri,
    language: "en",
    image: item.image || '',
    favicon: item.favicon || '',
    copyright: "2021",
    feedLinks: {
      json: item.formatUrls['json1.0'].uri,
      rss: item.formatUrls['rss2.0'].uri,
      atom: item.formatUrls['atom1.0'].uri
    },
    author: {
      name: siteDetails.maintainer || "",
      email: siteDetails.maintainerEmail || "",
      link: siteDetails.browserRoot || ''
    }
  })
  _.each(accumulators.members, (member) => {
    const feedItem = {
      title: _.get(member, 'memberMetadata.frontMatter.title'),
      date: moment(_.get(member, 'memberMetadata.frontMatter.date')).toDate(),
      description: _.get(member, 'memberMetadata.raw'),
      content: _.get(member, 'memberMetadata.raw'),
      id: _.get(member, 'memberUri'),
      link: _.get(member, 'memberUri'),
      author: [{
        name: _.get(member, 'memberMetadata.frontMatter.author') || "",
        email: _.get(member, 'memberMetadata.frontMatter.email') || "",
        link: siteDetails.browserRoot || '',
      }],
      contributor: [],
      image: '',
    }
    if (feedItem.title) {
      feed.addItem(feedItem)
    }
  })
  if (feedType === 'rss2.0') {
    return feed.rss2()
  } else if (feedType === 'atom1.0' ) {
    return feed.atom1()
  } else if (feedType === 'json1.0' ) {
    return feed.json1()
  }
  return ''
}

const renderers = {
  html: {
    renderFunction: renderHTML,
    ContentType: 'text/html; charset=utf-8',
  },
  'rss2.0': {
    renderFunction: _.partial(renderFeed, 'rss2.0'),
    ContentType: 'application/rss+xml; charset=utf-8',
  },
  'atom1.0': {
    renderFunction: _.partial(renderFeed, 'atom1.0'),
    ContentType: 'application/atom+xml; charset=utf-8',
  },
  'json1.0': {
    renderFunction: _.partial(renderFeed, 'json1.0'),
    ContentType: 'application/json; charset=utf-8',
  },
}

function render({siteDescription, item, dependencies}) {
  const targetFormats = item.typeDef.formats
  const { siteDetails } = siteDescription
  const identifyUri = identifyUriBuilder(siteDescription)
  const renderedFormats = {
    content: [],
    path: [],
    ContentType: []
  }
  _.each(targetFormats, ({authoring, idTemplate}, formatName) => {
    // never overwrite an authoring format
    if (!authoring) {
      try {
        const url = expandUrlTemplateWithName({templateString: idTemplate, siteDetails, name: item.name})
        const path = urlToPath(url, siteDetails.pathRegex)
        const content = renderers[formatName].renderFunction({siteDetails, item, dependencies, identifyUri})
        renderedFormats.content.push(content)
        renderedFormats.path.push(path)
        renderedFormats.ContentType.push(renderers[formatName].ContentType)
      } catch(e) {
        console.error(e)
      }
    }
  })
  _.each(siteDetails.formats, ({sections}, formatName) => {
    _.each(sections, ({renderFrom, renderTo, sectionTitle}) => {
      if (renderFrom === item.uri) {
        try {
          const content = renderers[formatName].renderFunction({siteDetails, item, dependencies, identifyUri})
          renderedFormats.content.push(content)
          renderedFormats.path.push(_.trimStart(renderTo, '/'))
          renderedFormats.ContentType.push(renderers[formatName].ContentType)
        } catch(e) {
          console.error(e)
        }
      }
    })
  })
  return renderedFormats
}

module.exports = {
  parsePost,
  render,
}
