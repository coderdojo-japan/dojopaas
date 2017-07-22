var sacloud = require('sacloud');
var fs = require('fs');
var csv = require('comma-separated-values');
var Server = require('./lib/Server');

var list = __dirname + '/servers.csv';

if ('--test' === process.argv[2]) {
  var config = {
    defaultTag: 'dojopaas',
    zone: "29001", // サンドボックス
    api: "https://secure.sakura.ad.jp/cloud/zone/tk1v/api/cloud/1.1/",
    plan: 1001,
    packetfilterid: '112900927419',
    disk: {
      Plan: { ID: 4 },
      SizeMB: 20480,
      SourceArchive: { ID: "112900758037" }
    }
  }
} else {
  var config = {
    defaultTag: 'dojopaas',
    zone: "31002", // 石狩第二
    api: "https://secure.sakura.ad.jp/cloud/zone/is1b/api/cloud/1.1/", // 石狩第二
    plan: "1001", // 1コア、1GBメモリ
    packetfilterid: '112900922505', // www
    disk: {
      Plan: { ID: 4 }, // SSD
      SizeMB: 20480, // 20GB
      SourceArchive: { ID: "112900757970" } // Ubuntu 16.04
    }
  }
}

sacloud.API_ROOT = config.api;
var client = sacloud.createClient({
  accessToken        : process.env.SACLOUD_ACCESS_TOKEN,
  accessTokenSecret  : process.env.SACLOUD_ACCESS_TOKEN_SECRET,
  disableLocalizeKeys: false, // (optional;default:false) false: lower-camelize the property names in response Object
  debug              : false // (optional;default:false) output debug requests to console.
});

client.createRequest({
  method: 'GET',
  path  : 'server',
  body  : {
    Filter: {
      "Tags": config.defaultTag
    }
  }
}).send(function(err, result) {
  if (err) throw new Error(err);
  var servers = [];
  for (var i=0; i<result.response.servers.length; i++) {
    servers.push(result.response.servers[i].name)
  }
  fs.readFile(list, 'utf8', function (err, text) {
    var result = new csv(text, { header: true }).parse();
    var data = [];
    var promises = [];
    for (var i=0; i<result.length; i++) {
      promises.push(new Promise(function(resolve, reject) {
        var line = result[i];
        if (! servers.some(function(v){ return v === line.name }) ) {
          var tags = [config.defaultTag];
          tags.push(line.branch)
          var server = new Server(client);
          server.create({
            zone: config.zone,
            plan: config.plan,
            packetfilterid: config.packetfilterid,
            name: line.name,
            description: line.description,
            tags: tags,
            pubkey: line.pubkey,
            disk: config.disk,
            resolve: resolve
          })
        } else {
          resolve();
        }
      }));
    }
    Promise.all(promises).then(function() {
      client.createRequest({
        method: 'GET',
        path  : 'server',
        body  : {
          Filter: {
            "Tags": config.defaultTag
          }
        }
      }).send(function(err, result) {
        var servers = [];
        for (var i=0; i<result.response.servers.length; i++) {
          servers.push([
            result.response.servers[i].name,
            result.response.servers[i].interfaces[0].ipAddress,
            result.response.servers[i].description
          ])
        }
        var list = new csv(servers, {header: ["Name", "IP Address", "Description"]}).encode();
        fs.writeFile('instances.csv', list, function(error) {
          if (err) throw err;
          console.log('The CSV has been saved!');
        });
      });
    }).catch(function(error) {
      console.log(error)
    });
  });
});
