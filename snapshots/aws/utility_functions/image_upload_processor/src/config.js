const _ = require('lodash'); 
const ExifReader = require('exifreader');
const isSvg = require('is-svg')

function exifMeta(img) {
  let meta = {}
  try {
    meta = ExifReader.load(img, {expanded: true})
  } catch(e) {}
  let date
  try {
    const year = meta.exif.DateTimeOriginal.description.slice(0, 4)
    const month = meta.exif.DateTimeOriginal.description.slice(5, 7)
    const day = meta.exif.DateTimeOriginal.description.slice(8, 10)
    const hour = meta.exif.DateTimeOriginal.description.slice(11, 13)
    const minute = meta.exif.DateTimeOriginal.description.slice(14, 16)
    const second = meta.exif.DateTimeOriginal.description.slice(17, 19)
    date = {year, month, day, hour, minute, second}
  } catch(e) {
    const now = new Date()
    date = {
      year: now.getFullYear(),
      month: now.getMonth(),
      day: now.getUTCDate(),
      hour: now.getUTCHours(),
      minute: now.getUTCMinutes(),
      second: now.getUTCSeconds(),
    }
  }
  if (_.get(meta, 'exif.MakerNote')) {
    delete meta.exif.MakerNote
  }
  const ret = {
    image: img,
    meta: {
      file: meta.file,
      exif: meta.exif,
      xmp: meta.xmp,
      iptc: meta.iptc,
      // I think the gps is getters not data so it doesn't json nicely
      gps: meta.gps ? {
        Latitude: meta.gps.Latitude,
        Longitude: meta.gps.Longitude,
        Altitude: meta.gps.Altitude,
      } : null,
      timestamp: date.year + "-" + date.month + "-" + date.day + "T" +  date.hour + ":" + date.minute + ":" + date.second + ".000",
    },
    date
  };
  return ret
}

function parseImageId(key) {
  const keySegments = key.split('/')
  const idSegments = keySegments.slice(keySegments.length - 2).join('/').split('.')
  const ext = idSegments.pop()
  const id = idSegments.join('.')
  return {
    id,
    ext
  }
}

module.exports = {
  stages: {
    file: {
      index: 0,
      transformers: {
        mediaId: {
          helper: ({key}) => parseImageId(key),
            params: {
            key: { ref: 'event.Records[0].s3.object.decodedKey'}
          }
        },
        widths: { value: [50, 500] },
        bucket: {
          or: [
            {ref: 'event.bucket'},
            {ref: 'event.Records[0].s3.bucket.name'},
          ]
        },
        imageKey: {
          or: [
            {ref: 'event.imageKey'},
            {ref: 'event.Records[0].s3.object.decodedKey'},
          ]
        },
      },
      dependencies: {
        file: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.getObject'},
            explorandaParams: {
              Bucket: {ref: 'stage.bucket'},
              Key: {ref: 'stage.imageKey'},
            }
          }
        }
      }
    },
    fileType: {
      index: 1,
      dependencies: {
        fileType: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.FILE_TYPE.fromBuffer'},
            explorandaParams: {
              file: { ref: 'file.results.file[0].Body'}
            }
          }
        }
      }
    },
    imageType: {
      index: 2,
      transformers: {
        imageType: {
          helper: ({image, fileType}) => {
            if (_.get(fileType, 'ext') === "xml" && isSvg(image)) {
              return {
                ext: 'svg',
                mime: 'image/svg+xml'
              }
            }
            return fileType
          },
          params: {
            image: { ref: 'file.results.file[0].Body'},
            fileType: { ref: 'fileType.results.fileType[0]'}
          }
        }
      },
    },
    image: {
      index: 3,
      dependencies: {
        image: {
          action: 'exploranda',
          params: {
            accessSchema: {
              value: {
                dataSource: 'SYNTHETIC',
                value: { path: _.identity},
                transformation: ({meta}) => {
                  return meta
                }
              }
            },
            explorandaParams: {
              meta: {
                helper: ({image, fileType}) => {
                  if (!fileType) {
                    return { image }
                  }
                  const { ext } = fileType
                  let meta = {image}
                  if (['png', 'jpg', 'tif', 'webp', 'heic'].indexOf(ext) !== -1) {
                    meta = exifMeta(image)
                  }
                  meta.fileType = fileType
                  return meta
                },
                params: {
                  image: { ref: 'file.results.file[0].Body'},
                  fileType: { ref: 'imageType.vars.imageType'}
                }
              }
            }
          }
        }
      }
    },
    rotatedImage: {
      index: 4,
      transformers: {
        useSharp: {
          helper: ({ext}) => ['png', 'jpg', 'tif', 'webp', 'heic'].indexOf(ext) !== -1,
          params: {
            ext: { ref: 'imageType.vars.imageType.ext'},
          }
        },
      },
      dependencies: {
        rotatedImage: {
          condition: {ref: 'stage.useSharp'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.sharp.rotate.rotateOne'},
            explorandaParams: {
              image: { ref: 'image.results.image[0].image' }
            }
          }
        }
      }
    },
    resizeImage: {
      index: 5,
      transformers: {
        widths: { value: [50, 500] }
      },
      dependencies: {
        resizedImage: {
          condition: {ref: 'rotatedImage.vars.useSharp'},
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.sharp.resize.resizeOne'},
            explorandaParams: {
              image: { ref: 'rotatedImage.results.rotatedImage[0]' },
              width: {ref: 'stage.widths'},
              withoutEnlargement: {value: true},
            }
          }
        }
      }
    },
    saveResizedImage: {
      index: 6,
      transformers: {
        widths: { value: [50, 500] }
      },
      dependencies: {
        save: {
          action: 'exploranda',
          params: {
            accessSchema: { value: 'dataSources.AWS.s3.putObject' },
            explorandaParams: {
              Bucket: { value: '${io_config.output_bucket}' },
              Body: { or: [
                { ref: 'resizeImage.results.resizedImage' },
                { 
                  helper: ({widths, image}) => _.times(widths.length, _.constant(image)),
                  params: {
                    widths: { ref: 'stage.widths' },
                    image: { ref: 'image.results.image[0].image' }
                  }
                } ],
              },
              ContentType: { ref: 'imageType.vars.imageType.mime'},
              Key: {
                helper: ({widths, ext, mediaId}) => _.map(widths, (w) => "${trim(io_config.output_path, "/")}/" + mediaId + "/" + w + "." + ext),
                params: {
                  ext: { ref: 'imageType.vars.imageType.ext'},
                  mediaId: { ref: 'file.vars.mediaId.id' },
                  widths: { ref: 'stage.widths' },
                }
              }
            }
          }
        }
      },
    },
    tagUploadComplete: {
      index: 7,
      dependencies: {
        tag: {
          action: 'exploranda',
          params: {
            accessSchema: {value: 'dataSources.AWS.s3.putObjectTagging'},
            params: {
              explorandaParams: {
                Key: {ref: 'event.Records[0].s3.object.decodedKey'},
                Bucket: {ref: 'event.Records[0].s3.bucket.name'},
                Tagging: {value: {
                  TagSet: ${jsonencode(io_config.tags)}
                }}
              }
            }
          },
        },
      },
    },
  }
}
