var Server = function(client) {
  this.client = client;
}

Server.prototype.create = function(settings) {
  var client = this.client;
  var self = this;

  Promise.resolve()
  // インスタンスを作成
  .then(function() {
    return new Promise(function(resolve, reject) {
      console.log('Create a server for '+settings.name+'.')
      client.createRequest({
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
      }).send(function(err, result) {
        if (err) throw new Error(err);
        this.serverId = result.response.server.id;
        resolve(result.response.server.id);
      });
    });
  })
  // ネットワークインターフェースを作成
  .then(function(serverId) {
    return new Promise(function(resolve, reject) {
      console.log('Create a network interface.');
      client.createRequest({
        method: 'POST',
        path  : 'interface',
        body  : {
          Interface: {
            Server: {
              ID: serverId
            }
          }
        }
      }).send(function(err, result) {
        if (err) reject(err)
        resolve({
          serverId: serverId,
          interfaceId: result.response.interface.id
        });
      });
    });
  })
  // ネットワークインターフェースを接続
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      console.log('Connect network interface.');
      client.createRequest({
        method: 'PUT',
        path  : 'interface/'+params.interfaceId+'/to/switch/shared'
      }).send(function(err, result) {
        if (err) reject(err)
        resolve({
          serverId: params.serverId,
          interfaceId: params.interfaceId
        });
      });
    });
  })
  // パケットフィルターを適用
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      console.log('Apply packet filter.');
      client.createRequest({
        method: 'PUT',
        path  : 'interface/'+params.interfaceId+'/to/packetfilter/'+settings.packetfilterid
      }).send(function(err, result) {
        if (err) reject(err)
        resolve({
          serverId: params.serverId
        });
      });
    });
  })
  // ディスクを作成
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      console.log('Create a disk.');
      var disk = settings.disk;
      disk.Zone = { ID: settings.zone };
      disk.Name = settings.name;
      disk.Description = settings.description;
      client.createRequest({
        method: 'POST',
        path  : 'disk',
        body  : {
          Disk: disk
        }
      }).send(function(err, result) {
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
  // ディスクをインスタンスに接続
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      console.log('Connect to the disk.');
      client.createRequest({
        method: 'PUT',
        path: 'disk/'+params.diskId+'/to/server/'+params.serverId
      }).send(function(err, result) {
        if (err) reject(err)
        resolve({
          serverId: params.serverId,
          diskId: params.diskId
        });
      });
    });
  })
  // SSH接続用の公開鍵を書き込みしてサーバーを起動
  .then(function(params) {
    return new Promise(function(resolve, reject) {
      console.log('Setup ssh key.');
      var body = {};
      if (settings.notes) {
        body = {
          SSHKey: {
            PublicKey: settings.pubkey
          },
          Notes: settings.notes
        }
      } else {
        body = {
          SSHKey: {
            PublicKey: settings.pubkey
          }
        }
      }
      var request = client.createRequest({
        method: 'PUT',
        path: 'disk/'+params.diskId+'/config',
        body: body
      });
      var timer = setInterval(function(){
        request.send(function(err, result) {
          if (err) {
            console.log(result.response.status);
            console.log('Copying image for '+settings.name+'...')
          } else if (! err) {
            var request = client.createRequest({
              method: 'PUT',
              path: 'server/'+params.serverId+'/power'
            });
            clearInterval(timer);
            request.send(function(err, result) {
              if (err) {
                reject(err)
              }
              console.log('Start server: '+params.serverId+' for '+settings.name+'.');
              clearInterval(timer);
              resolve();
            });
          } else {
            clearInterval(timer);
            reject(err);
          }
        });
      }, 10000);
    });
  })
  .then(function() {
    settings.resolve(this.serverId)
  })
  .catch(function(err) {
    console.log(this.serverId+' will be destroyed.')
    self.destroy(this.serverId); // エラー時はインスタンスを削除
    throw new Error(err);
  })
}

Server.prototype.destroy = function(serverId) {
  var client = this.client;
  Promise.resolve()
  // インスタンスを停止
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
  // インスタンスを削除
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
          if (err && '409 Conflict' === result.response.status) {
            console.log('Shutting down ...')
          } else if (! err) {
            clearInterval(timer);
            resolve();
          } else {
            clearInterval(timer);
            reject(err);
          }
        })
      }, 10000);
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
