// Generated by CoffeeScript 1.9.3
var _, fs, path;

_ = require('lodash');

fs = require('fs');

path = require('path');

module.exports = _.object(_.map(fs.readdirSync(__dirname), function(file) {
  var filename;
  filename = path.basename(file, '.js');
  if (filename === 'index') {
    return;
  }
  return [filename, require("./" + filename)];
}));
