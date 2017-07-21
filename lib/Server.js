var Server = function(client) {
  this.client = client;
}

Server.prototype.create = function(settings) {
  var client = this.client;
  var self = this;

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
        this.serverId = result.response.server.id;
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
        if (err) reject(err)
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
        if (err) reject(err)
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
        if (err) reject(err)
        resolve({
          serverId: params.serverId
        });
      });
    });
  })
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      var disk = settings.disk;
      disk.Zone = { ID: settings.zone };
      disk.Name = settings.name;
      disk.Description = settings.description;
      var request = client.createRequest({
        method: 'POST',
        path  : 'disk',
        body  : {
          Disk: disk
        }
      });
      request.send(function(err, result) {
        if (err) reject(err);
        if ('undefined' === typeof result.response.disk) {
          reject('Can not create a disk.');
        } else {
          resolve({
            serverId: params.serverId,
            diskId: result.response.disk.id
          });
        }
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
        if (err) reject(err)
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
              if (err) reject(err)
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
    settings.resolve(this.serverId)
  })
  .catch(function(err) {
    console.log(this.serverId+' will be destroyed.')
    self.destroy(this.serverId)
    throw new Error(err);
  })
}

Server.prototype.destroy = function(serverId) {
  var client = this.client;
  Promise.resolve()
  .then(function() {
    return new Promise(function(resolve, reject) {
      client.createRequest({
        method: 'DELETE',
        path: 'server/'+serverId+'/power',
        body: {
          Force: true
        }
      }).send(function(err, result) {
        if (err) reject(err)
        resolve();
      })
    });
  })
  .then(function() {
    return new Promise(function(resolve, reject) {
      var timer = setInterval(function() {
        client.createRequest({
          method: 'DELETE',
          path: 'server/'+serverId,
          body: {
            WithDisk: true
          }
        }).send(function(err, result) {
          if (! err) {
            clearInterval(timer);
            resolve();
          }
        })
      }, 10000);
      setTimeout(function() {
        clearInterval(timer);
        reject('Can not destroy instance!');
      }, 60000);
    });
  })
  .then(function() {
    console.log('Deleted: '+serverId)
  })
  .catch(function(err) {
    throw new Error(err)
  })
}

module.exports = Server;
