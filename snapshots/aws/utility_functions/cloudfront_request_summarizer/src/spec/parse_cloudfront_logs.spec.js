const {parseResults, makeDynamoUpdates} = require('../parse_cloudfront_logs.js')
const fs = require('fs')
const _ = require('lodash')

const results1 = {
  '/posts/bezier_curves.html': 4,
  '/posts/some_functions_for_vases.html': 1,
  '/posts/distortion_fields.html': 1,
  '/posts/internet_history_000.html': 1,
  '/posts/early_november_check_in.html': 1,
  '/posts/salem_history_000.html': 2,
  '/posts/Some%2520more%2520rock%2520portraits.html': 11,
  '/posts/treasure_hunt_002.html': 2,
  '/posts/mid_june_check_in.html': 1,
  '/posts/treasure_hunt_flint.html': 1,
  '/posts/treasure_hunt_001.html': 2,
  '/posts/thinking_about_state.html': 1,
  '/posts/domain_boundaries.html': 1,
  '/posts/isolation_proposal_001.html': 1,
  '/posts/why_has_it_taken_this_long.html': 1,
  '/posts/unofficial_ui_survey.html': 1,
  '/posts/how_things_change.html': 1,
  '/posts/practitioner_journey.html': 1,
  '/posts/practitioner_inn_000.html': 1,
  '/posts/revenge_of_hateoas.html': 1,
  '/posts/indie_web_camp_east_rsvp.html': 5,
  '/posts/why_website.html': 1,
  '/posts/login_system_notes.html': 1
}

const results2 = {
  '/posts/internet_history_000.html': 1,
  '/posts/early_november_check_in.html': 1,
  '/posts/indie_web_camp_east_rsvp.html': 8,
  '/posts/anatomy_of_a_web_service.html': 3,
  '/posts/internet_history_002.html': 1,
  '/posts/bezier_curves.html': 1,
  '/posts/distortion_fields.html': 1,
  '/posts/the_roof_of_the_auditorium.html': 1
}

describe('parseResults', () => {
  it('test1', (done) => {
    const csvFilename = __dirname + '/support/2aa67b61-00bb-4688-bf80-64d4a9ebb90e.csv' 
    parseResults({buf: fs.readFileSync(csvFilename)}, (e, r) => {
      if (e) {
        console.log(e)
      }
      expect(r.hits).toEqual(results1)
      expect(_.reduce(r.hits, (t, v) => t + v, 0)).toEqual(43)
      done()
    })
  })
  it('test2', (done) => {
    const csvFilename = __dirname + '/support/42c72cdd-54d7-41c3-be1e-57f1c0a8125f.csv' 
    parseResults({buf: fs.readFileSync(csvFilename)}, (e, r) => {
      if (e) {
        console.log(e)
      }
      expect(r.hits).toEqual(results2)
      expect(_.reduce(r.hits, (t, v) => t + v, 0)).toEqual(17)
      done()
    })
  })
  it('test3', (done) => {
    const csvFilenames = _.map([...Array(24).keys()], (i) => __dirname + `/support/3407a00b-eebd-4bf4-88a6-4e5bf7be05e6/${_.padStart(i, 2, '0')}.csv`)
    _.map(csvFilenames, (csvFilename, indx) => {
      parseResults({buf: fs.readFileSync(csvFilename)}, (e, r) => {
        if (e) {
          console.log(e)
        }
      })
      if (indx === 23) {
        done()
      }
    })
  })
  it('test4', (done) => {
    const csvFilename = __dirname + '/support/fc472d8d-2a5c-4095-b848-e4e1de2965cb.csv' 
    parseResults({buf: fs.readFileSync(csvFilename)}, (e, r) => {
      if (e) {
        console.log(e)
      }
      console.log(r.hits)
      done()
    })
  })
})

const tableName = 'Test'

describe('makeDynamoUpdates', () => {
  it('test1', () => {
    console.log(makeDynamoUpdates(results1, tableName))
  })
  it('test1', () => {
    console.log(makeDynamoUpdates(results2, tableName))
  })
})

