const path = require('path');
const express = require('express');
const webpack = require('webpack');
const WebpackDevServer = require('webpack-dev-server');

const config = require('./config/webpack.dev');

const port = process.env.PORT || 3000;

const server = new WebpackDevServer(webpack(config), {
  publicPath: config.output.publicPath,
  hot: true,
  historyApiFallback: true
});

server.app.use(express.static(path.join(__dirname, 'static')));

server.app.get('/:docname', (req, res) => {
  res.sendFile(path.join(__dirname, 'static/index.html'));
});

/* eslint-disable no-console */
server.listen(port, 'localhost', err => {
  if (err) {
    return console.log(err);
  }
  console.log(`Listening at http://localhost:${port}`);
});

const spawn = require('child_process').spawn;
spawn(
  'node_modules/.bin/mocha',
  ['--compilers', 'js:babel-core/register', '--watch', 'test/tests'],
  {stdio: 'inherit'}
);
