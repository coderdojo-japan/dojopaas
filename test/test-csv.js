const fs = require('fs');
const csv = require('comma-separated-values');
const assert = require('assert');

fs.readFile('./servers.csv', 'utf8', function (err, text) {
  var result = new csv(text, { header: true }).parse();
  for (var i=0; i<result.length; i++) {
    assert.deepEqual(true, !! result[i].name);
    assert.deepEqual(true, !! result[i].branch);
    assert.deepEqual(true, !! result[i].description);
    assert.deepEqual(true, !! result[i].pubkey);
    assert.deepEqual(true, !! result[i].name.match(/^[a-z0-9\-]+$/));
    assert.deepEqual(true, !! result[i].branch.match(/^[a-z0-9\-]+$/));
  }
})
