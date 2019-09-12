#!/usr/bin/env ruby
class SakuraServerUserAgent
  require 'jsonclient'

  SAKURA_BASE_URL     = 'https://secure.sakura.ad.jp/cloud/zone'
  SAKURA_CLOUD_SUFFIX = 'api/cloud'
  SAKURA_API_VERSION  = '1.1'

  SAKURA_TOKEN        = ENV.fetch('SAKURA_TOKEN')
  SAKURA_TOKEN_SECRET = ENV.fetch('SAKURA_TOKEN_SECRET')

  # jsのserver.createで使っているフィールドを参考
  def initialize(zone:0, packetfilterid:nil, name:nil, description:nil, zone_id:"is1b",
                 tags:nil, pubkey:nil, disk:{}, resolve:nil)
    @zone           = zone
    @packetfilterid = packetfilterid
    @name           = name
    @description    = description
    @tags           = tags || ['dojopaas']
    @pubkey         = pubkey
    @resolve        = resolve
    @disk           = disk || { Plan:{ID:4}, SizeMB:20480 } #plan is SSD, sizeMB is 20GB
    @plan           = 1001 # 1core 1Gb memory
    @notes          = [ ID:"112900928939" ]  # See https://secure.sakura.ad.jp/cloud/iaas/#!/pref/script/.
    @sakura_zone_id = zone_id

    @client = JSONClient.new
    @client.set_auth(create_endpoint(nil),SAKURA_TOKEN, SAKURA_TOKEN_SECRET)
  end

  # server.createに対応
  # 引数があると、オブジェクトの状態を変えつつそちらを使う
  def create(params)
    @name        = params[:name] || @name
    @description = params[:description] || @description
    @pubkey      = params[:pubkey] || @pubkey

    create_server_instance()
    create_network_interface()
    apply_packet_filter()
    create_a_disk()
    disk_connection()
    setup_ssh_key()
  end


  # createとdestroyで独自に引数を取れるようにしておく

  #インスタンス作成
  def create_server_instance(params = nil)
    puts "Create a server for #{@name}."
    query = {
      :Server => {
        :Zone        => @zone,
        :ServerPlan  => params[:plan] || @plan,
        :Name        => params[:name] || @name,
        :Description => params[:Description] || @description,
        :Tags        => params[:tags] || @tags
      }
    }
    response   = send_request('post','server', params)
    @server_id = response['server']['id']

    rescue => exception
      puts exception
  end

  #ネットワークインターフェイスの作成
  def create_network_interface(server_id = nil)
    query = {
      :interface => {
        :Server => {
          :ID => server_id || @server_id
        }
      }
    }
    response      = send_request('post', 'interface', query)
    @interface_id = response['interface']['id']

    rescue => exception
      puts exception
  end

  #ネットワークインターフェイスの接続
  def connect_network_interface(interfce_id = nil)
    @interface_id ||= interface_id
    response      = send_request('put', "interface/#{interface_id}/to/switch/shared",nil)
    @server_id    = response['serverId']
    @interface_id = response['interfaceId']

    rescue => exception
      puts exception
  end

  #パケットフィルターを適用
  def apply_packet_filter(params = nil)
    @interface_id     ||= params[:interface_id]
    @packet_filter_id ||= params[:packet_filter_id]
    response      = send_request('put', "interface/#{interface_id}/to/packetfilter/#{@packet_filter_id}",nil)
    @server_id    = response['serverId']

    rescue => exception
      puts exception
  end

  # ディスク作成
  def create_a_disk(disk_param = nil)
    if @disk.empty?
      @disk = disk_param
    else
      @disk = {
        :Zone => { :ID => @zone}, 
        :Name => @name,
        :Description => @description
      }
    end
    response    = send_request('post','disk',{:Disk => @disk})
    @disk[:id]  = response['disk']['id']

    rescue => exception
      puts exception
      puts 'Can not create a disk.'
  end

  def disk_connection(disk_param = nil)
    if @disk.empty?
      @disk = disk_param
    end
    response = send_request('put',"disk/#{@disk['id']}/to/server/#{@server_id}",nil)

    rescue => exception
      puts exception
  end

  def update_startup_scripts(text)
    body = {Note:{Content:text}}
    send_request('put',"note/#{@notes[:ID]}",body)
  end

  def setup_ssh_key(params = nil)
    put_ssh_key()
    _copying_image()
  end

  def get_servers()
    body = { Filter: {Tags: @tags.first} }
    send_request('get','server',body) 
  end 

  def get_archives()
    send_request('get','archive',nil) 
  end

  private

  def _put_ssh_key
    body = { 
      :SSHKey => {
        :PublicKey => @pubkey
      }
    }
    if !@notes.empty?
      body[:SSHKey][:Notes] = @notes
    end
    send_request('put',"disk/#{@disk['id']}/config",body)
  end

  def _copying_image
    send_request('put',"server/#{@server_id}/power")

    rescue => exception
      puts exception
  end

  # URI(エンドポイント)を作成する
  def create_endpoint(path)
    "#{SAKURA_BASE_URL}/#{@sakura_zone_id}/#{SAKURA_CLOUD_SUFFIX}/#{SAKURA_API_VERSION}/#{path}"
  end

  # 実際に送信する
  def send_request(http_method,path,query)
    endpoint = create_endpoint(path)
    response = @client.send(http_method,endpoint,:query => query, :follow_redirect => true)
    if response.body.empty?
      raise "Can not send #{http_method} request."
    else
      response.body
    end
  end
end
