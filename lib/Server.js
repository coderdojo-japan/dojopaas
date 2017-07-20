var Server = function(client) {
  this.client = client;
}

Server.prototype.create = function(settings) {
  var client = this.client;

  Promise.resolve()
  .then(function() {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'POST',
        path  : 'server',
        body  : {
          Server: {
            Zone       : { ID: settings.zone },
            ServerPlan : { ID: settings.plan },
            Name       : settings.name,
            Description: settings.description,
            Tags       : settings.tags
          }
        }
      });

      // サーバーを作成するリクエストを送信
      request.send(function(err, result) {
        if (err) throw new Error(err);
        resolve(result.response.server.id);
      });
    });
  })
  .then(function(serverId) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'POST',
        path  : 'interface',
        body  : {
          Interface: {
            Server: {
              ID: serverId
            }
          }
        }
      });
      request.send(function(err, result) {
        if (err) console.log("Error: Please delete " + serverId + " on control panel.");
        resolve({
          serverId: serverId,
          interfaceId: result.response.interface.id
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'PUT',
        path  : 'interface/'+params.interfaceId+'/to/switch/shared'
      });
      request.send(function(err, result) {
        if (err) console.log("Error: Please delete " + params.serverId + " on control panel.");
        resolve({
          serverId: params.serverId,
          interfaceId: params.interfaceId
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'PUT',
        path  : 'interface/'+params.interfaceId+'/to/packetfilter/'+settings.packetfilterid
      });
      request.send(function(err, result) {
        if (err) console.log("Error: Please delete " + params.serverId + " on control panel.");
        resolve({
          serverId: params.serverId
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'POST',
        path  : 'disk',
        body  : {
          Disk: {
            Zone: { ID: settings.zone },
            Plan: { ID: 4 },
            Name: settings.name,
            Description: settings.description,
            SizeMB: settings.size,
            SourceArchive: { ID: settings.image }
          }
        }
      });
      request.send(function(err, result) {
        if (err) console.log("Error: Please delete " + params.serverId + " on control panel.");
        resolve({
          serverId: params.serverId,
          diskId: result.response.disk.id
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'PUT',
        path: 'disk/'+params.diskId+'/to/server/'+params.serverId
      });
      request.send(function(err, result) {
        if (err) console.log("Error: Please delete " + params.serverId + " on control panel.");
        resolve({
          serverId: params.serverId,
          diskId: params.diskId
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var request = client.createRequest({
        method: 'PUT',
        path: 'disk/'+params.diskId+'/config',
        body: {
          SSHKey: {
            PublicKey: settings.pubkey
          }
        }
      });
      var timer = setInterval(function(){
        request.send(function(err, result) {
          if (!err) {
            var request = client.createRequest({
              method: 'PUT',
              path: 'server/'+params.serverId+'/power'
            });
            request.send(function(err, result) {
              if (err) console.log("Error: Please delete " + params.serverId + " on control panel.");
              console.log('Start server: '+params.serverId);
              resolve();
            });
            clearInterval(timer);
          }
        });
      }, 30000);
    });
  })
  .then(function() {
    settings.resolve()
  })
}

module.exports = Server;
