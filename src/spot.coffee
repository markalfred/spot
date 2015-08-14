require('dotenv').load()
_       = require 'lodash'
fs      = require 'fs'
ps      = require 'child_process'
temp    = require 'temp'
moment  = require 'moment'
request = require 'request'
blessed = require 'blessed', screen

AUTH_TOKEN = null
REQUEST_OPTS = null
IMG_DIR = null
SOUND_DIR = null

setup = ->
  getToken()
  temp.track()
  temp.mkdir 'images', (err, dirPath) -> IMG_DIR = dirPath
  temp.mkdir 'sound', (err, dirPath) -> SOUND_DIR = dirPath

render = ->
  playlists.focus()
  searchModal.hide()
  # searchModal.show()
  # searchModal.focus()
  # searchInput.input 'Search', '', performSearch
  screen.render()

getToken = ->
  opts =
    method: 'POST'
    url: 'https://accounts.spotify.com/api/token'
    headers:
      'Authorization': "Basic #{new Buffer("#{process.env.CLIENT_ID}:#{process.env.CLIENT_SECRET}").toString('base64')}"
      'Content-Type':'application/x-www-form-urlencoded'
    form:
      'grant_type': 'client_credentials'

  request opts, (err, res, body) ->
    AUTH_TOKEN = JSON.parse(body).access_token
    REQUEST_OPTS = headers: 'Authorization': "Bearer #{AUTH_TOKEN}"
    render()
    getPlaylists AUTH_TOKEN

getPlaylists = (token) ->
  options =
    url: "https://api.spotify.com/v1/users/#{process.env.USERNAME}/playlists?limit=50"
    headers:
      'Authorization': "Bearer #{token}"

  request options, (err, res, body) ->
    console.log err if err
    playlists.collection = playlistJson = JSON.parse(body)
    playlists.setItems _.pluck(playlistJson.items, 'name')
    screen.render()

setup()

CONTENT_HEADER = ['SONG', 'ARTIST', 'ALBUM', 'LENGTH']
SEARCH_URL = 'https://api.spotify.com/v1/search?type=track&limit=50&q='

screen = blessed.screen
  smartCSR: true
  dockBorders: true

screen.title = 'Spot'

title = blessed.text
  parent: screen
  top: 'top'
  left: 'center'
  align: 'center'
  height: 1
  style:
    fg: 'green'
  tags: true
  content: '{bold} Spot {/}'

sidebar = blessed.box
  parent: screen
  top: title.height
  left: 0
  height: "100%-#{title.height}"
  border: 'line'
maxWidth = 40
sidebar.width = maxWidth if sidebar.width > maxWidth

main = blessed.box
  parent: screen
  top: title.height
  left: sidebar.width - 1
  right: 'right'
  height: "100%-#{title.height}"
  width: "100%-#{sidebar.width}"
  border: 'line'

content = blessed.listtable
  parent: main
  top: 0
  left: 0
  height: '100%-2'
  width: '100%-2'
  scrollable: true
  border: true
  keys: true
  vi: true
  mouse: true
  style:
    cell:
      fg: 'grey'
      selected:
        fg: 'white'
        bold: true
    header:
      fg: 'grey'
      bold: true
  scrollbar:
      ch: ' '
      inverse: true

art = blessed.png
  parent: sidebar
  bottom: 0
  left: 0
  height: 16
  width: '100%-2'

playlists = blessed.list
  parent: sidebar
  top: 0
  left: 0
  height: 'shrink'
  width: '100%-2'
  scrollable: true
  mouse: true
  keys: true
  vi: true
  content: 'Loading...'
  padding:
    top: 0
    right: 1
    bottom: 0
    left: 1
  style:
    selected:
      fg: 'white'
      bold: true
    item:
      fg: 'grey'
  scrollbar:
      ch: ' '
      inverse: true

playlists.height =
  screen.height -
  title.height -
  art.height -
  2

searchModal = blessed.box
  parent: screen
  shadow: true
  left: 'center'
  top: 'center'
  width: '50%'
  height: '50%'
  style:
    bg: 'white'
  border: 'line'

searchInput = blessed.prompt
  parent: searchModal
  top: 1
  left: 'center'
  height: 'shrink'
  width: '75%'
  tags: true

setContentRows = (rows) ->
  content.collection = rows
  rows = _.map content.collection, (c) ->
    [
      c.name
      _.map(c.artists, 'name').join(', ')
      c.album.name
      moment(c.duration_ms).format('m:ss')
    ]
  content.setRows [CONTENT_HEADER].concat(rows)

performSearch = (err, query) ->
  searchModal.hide()
  screen.render()
  return unless query?.length

  request SEARCH_URL + query.split(' ').join('+'), (err, res, body) ->
    setContentRows JSON.parse(body).tracks.items
    screen.render()

getImage = (filename) ->
  SPOTIFY_URL = 'https://i.scdn.co/image'
  exists =
    try fs.statSync("#{IMG_DIR}/#{filename}.png").isFile()
    catch e then false

  if exists
    art.setImage "#{IMG_DIR}/#{filename}.png"
    screen.render()
  else
    request
      .get "#{SPOTIFY_URL}/#{filename}"
      .pipe fs.createWriteStream("#{IMG_DIR}/#{filename}")
      .on 'error', (err) -> console.log(err)
      .on 'finish', ->
        ps.exec "sips #{IMG_DIR}/#{filename} -s format png --out #{IMG_DIR}/#{filename}.png", ->
          art.setImage "#{IMG_DIR}/#{filename}.png"
          screen.render()

playProcess = null

playSample = (filename) ->
  SPOTIFY_URL = 'https://p.scdn.co/mp3-preview'
  exists =
    try fs.statSync("#{SOUND_DIR}/#{filename}").isFile()
    catch e then false

  if exists
    playProcess?.kill()
    playProcess = ps.exec "afplay #{SOUND_DIR}/#{filename}"
  else
    request
      .get "#{SPOTIFY_URL}/#{filename}"
      .pipe fs.createWriteStream("#{SOUND_DIR}/#{filename}")
      .on 'error', (err) -> console.log err
      .on 'finish', ->
        playProcess?.kill()
        playProcess = ps.exec "afplay #{SOUND_DIR}/#{filename}"

playlists.key 'enter', ->
  opts = _.extend REQUEST_OPTS, url: playlists.collection.items[playlists.selected].tracks.href
  request opts, (err, res, body) ->
    setContentRows _.pluck JSON.parse(body).items, 'track'
    content.focus()
    screen.render()

content.key 'enter', ->
  track = content.collection[content.selected - 1]
  getImage track.album.images[2].url.split('/').pop()
  playSample track.preview_url.split('/').pop()

screen.key 'q', ->
  playProcess?.kill()
  process.exit(0)

screen.key 'tab', ->
  if screen.focused is content
    playlists.focus()
  else if screen.focused is playlists
    content.focus()

screen.key '/', ->
  searchModal.show()
  searchInput.input 'Search', '', performSearch
  screen.render()
