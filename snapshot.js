const path = require('path')
const fs = require('fs')
const _ = require('lodash')
const asyncLib = require('async')

function recursiveModuleRelativizingCopy({source, dest}, cb) {
  const srcRegex = new RegExp(`^${path.join(source, '')}`)
  const modulePathRegex = new RegExp("github.com/RLuckom/terraform_modules//([^\"?]*)([^\"]*)\"", "g")
  asyncLib.parallel(_.map(filterTree(source, _.constant(true)), (filepath) => {
    const destpath = path.join(dest, filepath)
    fs.mkdirSync(path.dirname(destpath), {recursive: true})
    return (callback) => {
      if (_.endsWith(filepath, '.tf')) {
        const filedir = path.dirname(filepath)
        fs.readFile(filepath, 'utf8', (err, contents) => {
          if (err || !_.isString(contents)) {
            return callback(err || `contents was not a string, got ${typeof contents} : ${contents}`)
          }
          const newContents = contents.replace(modulePathRegex, (match, modulepath, refspec) => {
            const relpath = path.relative(filedir, modulepath) + '"'
            if (process.env.NODE_DEBUG) {
              console.log(`changing ${match} to ${relpath} in file ${filepath} and moving to ${destpath}`)
            }
            if (refspec) {
              console.warn(`Removing reference ${refspec} when changing ${match} to ${relpath} in file ${filepath} and moving to ${destpath}`)
            }
            return relpath
          })
          return fs.writeFile(destpath, newContents, callback)
        })
        return
      } else {
        fs.copyFile(filepath, destpath, callback) 
        return
      }
    }
  }), cb)
}

function filterTree(start, f) {
  if (fs.lstatSync(start).isDirectory()) {
    return _.flatten(_.map(fs.readdirSync(start), (name) => filterTree(path.join(start, name), f)))
  }
  return f(start) ? start : []
}

function makeSnapshot(dirsToSnapshot) {
  asyncLib.parallel(_.map(dirsToSnapshot, (dir) => {
    return (callback) => {
      recursiveModuleRelativizingCopy({source: './' + dir, dest: './snapshots/'}, callback)
    }
  }))
}

const dirsToSnapshot = [
  'aws',
  'protocols',
  'themes'
]

makeSnapshot(dirsToSnapshot)
