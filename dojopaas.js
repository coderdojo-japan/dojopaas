var sacloud = require('sacloud');

/// 石狩第一
var zone = "31002";
var api = "https://secure.sakura.ad.jp/cloud/zone/is1b/api/cloud/1.1/"

var plan = "1001" // 1コア、1GBメモリ
var image = "112900757970" // Ubuntu 16.04

var packetfilterid = '112900922505' // www

sacloud.API_ROOT = api;
var client = sacloud.createClient({
  accessToken        : process.env.SACLOUD_ACCESS_TOKEN,
  accessTokenSecret  : process.env.SACLOUD_ACCESS_TOKEN_SECRET,
  disableLocalizeKeys: false,// (optional;default:false) false: lower-camelize the property names in response Object
  debug              : false// (optional;default:false) output debug requests to console.
});

var request = client.createRequest({
  method: 'POST',
  path  : 'server',
  body  : {
    Server: {
      Zone       : { ID: zone },
      ServerPlan : { ID: plan },
      Name       : 'test-server.jp',
      Tags       : ['dojopaas']
    }
  }
});

request.send(function(err, result) {
  if (err) console.log(result.response);
  var request = client.createRequest({
    method: 'POST',
    path  : 'interface',
    body  : {
      Interface: {
        Server: {
          ID: result.response.server.id
        }
      }
    }
  });

  request.send(function(err, result) {
    if (err) console.log(result.response);
    var id = result.response.interface.id;
    var request = client.createRequest({
      method: 'PUT',
      path  : 'interface/'+id+'/to/switch/shared'
    });

    request.send(function(err, result) {
      if (err) console.log(result.response);
      var request = client.createRequest({
        method: 'PUT',
        path  : 'interface/'+id+'/to/packetfilter/'+packetfilterid
      });
      request.send(function(err, result) {
        if (err) console.log(result.response);
      });
    });
  });
});
