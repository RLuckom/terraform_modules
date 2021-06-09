const _ = require('lodash')
const utils = require('../render_utils')
const mockPostList = require('./support/mocks.json')
const fs = require('fs')
const trailTemplate = fs.readFileSync(__dirname + '/support/templates/trail.tmpl')
const postTemplate = fs.readFileSync(__dirname + '/support/templates/post.tmpl').toString('utf8')
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
    const {deleted: {trails: deletedTrails, posts: deletedPosts}, changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock, 'why_website')
    expect(changedPosts).toEqual([
      'diy_singer_66_belt',
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
    const {deleted: {trails: deletedTrails, posts: deletedPosts}, changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock, 'why_website')
    expect(changedPosts).toEqual([
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
    const {deleted: {trails: deletedTrails, posts: deletedPosts}, changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock, 'why_website')
    expect(deletedPosts).toEqual([
    ])
    expect(changedPosts).toEqual([
    ])
    expect(changedTrails).toEqual(['identity'])
    expect(deletedTrails).toEqual([
      'philosophy'
    ])
  })

  it('identifies when a post has been deleted', () => {
    const copyMock = _.cloneDeep(mockPostList)
    const whyWebsite = copyMock.pop()
    const {deleted: {trails: deletedTrails, posts: deletedPosts}, changed: {trails: changedTrails, posts: changedPosts}} = utils.findChanges(mockPostList, copyMock, 'why_website', true)
    expect(changedPosts).toEqual([
      'diy_singer_66_belt',
      'taking_down_windmills_from_the_inside',
    ])
    expect(deletedPosts).toEqual([
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
    //fs.writeFileSync(__dirname + '/support/tests/test4.json', JSON.stringify(annotated, null, 2))
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
    const rendered = utils.renderPostToHTML({runningMaterial, post: parsed, neighbors, postTemplate})
    //fs.writeFileSync(__dirname + '/support/tests/alpha_todos.html', rendered)
    const renderedMock = fs.readFileSync(__dirname + '/support/tests/alpha_todos.html').toString('utf8')
    expect(rendered).toEqual(renderedMock)
  })

  it('renders a trail', () => {
    const members = utils.getTrailMembers('practitioner-journey', utils.annotatePostList(mockPostList))
    const rendered = utils.renderTrailToHTML({trailId: 'practitioner-journey', runningMaterial, members, trailTemplate})
    //fs.writeFileSync(__dirname + '/support/tests/practitioner_journey.html', rendered)
    const mock = fs.readFileSync(__dirname + '/support/tests/practitioner_journey.html').toString('utf8')
    expect(rendered).toEqual(mock)
  })

  it('determines updates on delete', () => {
    const rendered = utils.determineUpdates({
      postTemplate,
      trailTemplate,
      postId: 'alpha_todos',
      isDelete: true, 
      runningMaterial,
      previousPostList: _.cloneDeep(mockPostList)
    })
    //fs.writeFileSync(__dirname + '/support/tests/delete_updates.json', JSON.stringify(rendered, null, 2))
    const mock = require(__dirname + '/support/tests/delete_updates.json')
    //console.log(JSON.stringify(rendered, null, 2))
    expect(rendered).toEqual(mock)
  })

  it('determines no updates on resave same', () => {
    const rendered = utils.determineUpdates({
      postTemplate,
      trailTemplate,
      postId: 'alpha_todos',
      runningMaterial,
      postText: post,
      previousPostList: _.cloneDeep(mockPostList)
    })
    //fs.writeFileSync(__dirname + '/support/tests/resave_updates.json', JSON.stringify(rendered, null, 2))
    const mock = require(__dirname + '/support/tests/resave_updates.json')
    //console.log(JSON.stringify(rendered, null, 2))
    rendered.parsedPost.frontMatter.createDate = rendered.parsedPost.frontMatter.createDate.toISOString()
    rendered.parsedPost.frontMatter.date = rendered.parsedPost.frontMatter.date.toISOString()
    rendered.newPostList[72].frontMatter.createDate = rendered.newPostList[72].frontMatter.createDate.toISOString()
    rendered.newPostList[72].frontMatter.date = rendered.newPostList[72].frontMatter.date.toISOString()
    expect(rendered).toEqual(mock)
  })

  it('determines updates on add new', () => {
    const previousPostList = _.filter(_.cloneDeep(mockPostList), (p) => p.id !== 'alpha_todos')
    const rendered = utils.determineUpdates({
      postTemplate,
      trailTemplate,
      postId: 'alpha_todos',
      runningMaterial,
      postText: post,
      previousPostList,
    })
    //fs.writeFileSync(__dirname + '/support/tests/add_updates.json', JSON.stringify(rendered, null, 2))
    const mock = require(__dirname + '/support/tests/add_updates.json')
    //console.log(JSON.stringify(rendered, null, 2))
    rendered.parsedPost.frontMatter.createDate = rendered.parsedPost.frontMatter.createDate.toISOString()
    rendered.parsedPost.frontMatter.date = rendered.parsedPost.frontMatter.date.toISOString()
    rendered.newPostList[76].frontMatter.createDate = rendered.newPostList[76].frontMatter.createDate.toISOString()
    rendered.newPostList[76].frontMatter.date = rendered.newPostList[76].frontMatter.date.toISOString()
    expect(rendered).toEqual(mock)
  })

  it('determines updates on date change', () => {
    const previousPostList = _.cloneDeep(mockPostList)
    const rendered = utils.determineUpdates({
      postTemplate,
      trailTemplate,
      postId: 'alpha_todos',
      runningMaterial,
      postText: post.toString('utf8').replace(/2021/g, '2020'),
      previousPostList,
    })
    //fs.writeFileSync(__dirname + '/support/tests/change_date.json', JSON.stringify(rendered, null, 2))
    const mock = require(__dirname + '/support/tests/change_date.json')
    //console.log(JSON.stringify(rendered, null, 2))
    rendered.parsedPost.frontMatter.createDate = rendered.parsedPost.frontMatter.createDate.toISOString()
    rendered.parsedPost.frontMatter.date = rendered.parsedPost.frontMatter.date.toISOString()
    rendered.newPostList[72].frontMatter.createDate = rendered.newPostList[72].frontMatter.createDate.toISOString()
    rendered.newPostList[72].frontMatter.date = rendered.newPostList[72].frontMatter.date.toISOString()
    expect(rendered).toEqual(mock)
  })
})
