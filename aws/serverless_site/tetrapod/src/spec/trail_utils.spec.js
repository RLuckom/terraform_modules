const _ = require('lodash')
const utils = require('../trail_utils')
const mockPostList = require('./support/mocks.json')
const fs = require('fs')
const trailTemplate = utils.compileTemplate(fs.readFileSync(__dirname + '/support/templates/trail.tmpl'))
const postTemplate = utils.compileTemplate(fs.readFileSync(__dirname + '/support/templates/post.tmpl'))
const post = fs.readFileSync(__dirname + '/support/posts/alpha_todos.md')

const emptyNavLinks = []
const navLinks = [{
  name: 'name',
  target: 'https://example.com/name'
}]

const runningMaterial = {
  browserRoot: "https://${domain_name}",
  domainName: "${domain_name}",
  postListUrl: "https://${domain_name}/index.html",
  title: "${site_title}",
  navLinks,
}

describe('utils', () => {
  it('try the thing', () => {
    expect(utils.hashTrailsAndPosts(mockPostList)).toEqual(require('./support/tests/test1.json'))
  })

  it('identifies when a post title has changed', () => {
    const copyMock = _.cloneDeep(mockPostList)
    const whyWebsite = copyMock.pop()
    whyWebsite.frontMatter.title = "new title"
    copyMock.push(whyWebsite)
    const {changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock)
    const {deleted: {trails: deletedTrails}} = utils.findChanges(mockPostList, copyMock)
    expect(changedPosts).toEqual([
      'diy_singer_66_belt',
      'why_website',
      'taking_down_windmills_from_the_inside'
    ])
    expect(changedTrails).toEqual([
      'identity', 'philosophy'
    ])
    expect(deletedTrails).toEqual([])
  })

  it('identifies when a post\'s trails have changed', () => {
    const copyMock = _.cloneDeep(mockPostList)
    const whyWebsite = copyMock.pop()
    whyWebsite.frontMatter.meta.trails.push("new trail")
    copyMock.push(whyWebsite)
    const {changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock)
    const {deleted: {trails: deletedTrails}} = utils.findChanges(mockPostList, copyMock)
    expect(changedPosts).toEqual([
      'why_website'
    ])
    expect(changedTrails).toEqual([
      'new trail'
    ])
    expect(deletedTrails).toEqual([])
  })

  it('identifies when a trail has no more members', () => {
    const copyMock = _.cloneDeep(mockPostList)
    const whyWebsite = copyMock.pop()
    whyWebsite.frontMatter.meta.trails = []
    copyMock.push(whyWebsite)
    const {deleted: {trails: deletedTrails}} = utils.findChanges(mockPostList, copyMock)
    const {changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock)
    expect(changedPosts).toEqual([
      'why_website',
    ])
    expect(changedTrails).toEqual(['identity'])
    expect(deletedTrails).toEqual([
      'philosophy'
    ])
  })

  it('parses a post', () => {
    const parsed = utils.parsePost('alpha_todos', post, runningMaterial.domainName)
    const mock = require('./support/tests/test2.json')
    mock.frontMatter.createDate = new Date(mock.frontMatter.createDate)
    mock.frontMatter.date = new Date(mock.frontMatter.date)
    expect(parsed).toEqual(mock)
  })

  it('annotates a post list', () => {
    const annotated = utils.annotatePostList(mockPostList)
    const mock = require(__dirname + '/support/tests/test4.json')
    expect(annotated).toEqual(mock)
  })

  it('finds post neighbors', () => {
    const neighbors = utils.getPostNeighbors('alpha_todos', mockPostList)
    const mock = require(__dirname + '/support/tests/test3.json')
    expect(neighbors).toEqual(mock)
  })

  it('finds trail members', () => {
    const members = utils.getTrailMembers('practitioner-journey', mockPostList)
    const mock = require(__dirname + '/support/tests/members.json')
    expect(members).toEqual(mock)
  })

  it('renders a post', () => {
    const parsed = utils.parsePost('alpha_todos', post, runningMaterial.domainName)
    const neighbors = utils.getPostNeighbors('alpha_todos', utils.annotatePostList(mockPostList))
    const rendered = utils.renderPostToHTML({runningMaterial, post: parsed, neighbors})
    const renderedMock = fs.readFileSync(__dirname + '/support/tests/alpha_todos.html').toString('utf8')
    expect(rendered).toEqual(renderedMock)
  })

  it('renders a trail', () => {
    const members = utils.getTrailMembers('practitioner-journey', utils.annotatePostList(mockPostList))
    const rendered = utils.renderTrailToHTML({trailId: 'practitioner-journey', runningMaterial, members})
    const mock = fs.readFileSync(__dirname + '/support/tests/practitioner_journey.html').toString('utf8')
    expect(rendered).toEqual(mock)
  })
})
