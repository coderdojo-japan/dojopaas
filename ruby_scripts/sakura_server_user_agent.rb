#!/usr/bin/env ruby
class SakuraServerUserAgent
  require 'pry'
  require 'jsonclient'

  SAKURA_BASE_URL     = 'https://secure.sakura.ad.jp/cloud/zone'
  SAKURA_CLOUD_SUFFIX = 'api/cloud'
  SAKURA_API_VERSION  = '1.1'

  SAKURA_TOKEN        = ENV.fetch('SAKURA_TOKEN')
  SAKURA_TOKEN_SECRET = ENV.fetch('SAKURA_TOKEN_SECRET')

  # jsのserver.createで使っているフィールドを参考
  def initialize(zone:0, packet_filter_id:nil, name:nil, description:nil, zone_id:"is1b",
                 tags:nil, pubkey:nil, resolve:nil)
    @zone             = zone
    @packet_filter_id = packet_filter_id
    @name             = name
    @description      = description
    @tags             = tags || ['dojopaas']
    @pubkey           = pubkey
    @resolve          = resolve
    @plan             = 1001 # 1core 1Gb memory
    @notes            = [ ID:112900928939 ]  # See https://secure.sakura.ad.jp/cloud/iaas/#!/pref/script/.
    @sakura_zone_id   = zone_id

    @isDebug = true
    @client = JSONClient.new
    @client.set_auth(create_endpoint(nil),SAKURA_TOKEN, SAKURA_TOKEN_SECRET)
  end

  # server.createに対応
  # 引数があると、オブジェクトの状態を変えつつそちらを使う
  def create(params)
    @name        = params[:name] || @name
    @description = params[:description] || @description
    @pubkey      = params[:pubkey] || @pubkey
    @tags        = ['dojopaas',params[:tag]]

    puts 'create_server_instance'
    create_server_instance()

    puts 'create_network_interface'
    create_network_interface()

    puts 'apply_packet_filter'
    apply_packet_filter()

    puts 'create_a_disk'
    disk_id = create_a_disk()

    puts 'disk_connection'
    disk_connection(disk_id)

    puts 'setup_ssh_key'
    setup_ssh_key(disk_id)

    puts 'server_shutdown'
    server_shutdown()

    puts 'server_start'
    server_start()
  end


  # createとdestroyで独自に引数を取れるようにしておく

  #インスタンス作成
  def create_server_instance()
    puts "Create a server for #{@name}."
    query = {
      Server:  {
        ServerPlan:   {ID:@plan.to_i},
        Name:         @name,
        Description:  @description,
        Tags:         @tags
      }
    }
    response   = send_request('post','server', query)
    @server_id = response['Server']['ID']

    rescue => exception
      puts exception
  end

  #ネットワークインターフェイスの作成
  def create_network_interface(server_id = nil)
    query = {
      :Interface => {
        :Server => {
          :ID => server_id || @server_id
        }
      }
    }
    response      = send_request('post', 'interface', query)
    @interface_id = response['Interface']['ID']

    rescue => exception
      puts exception
  end

  #ネットワークインターフェイスの接続
  def connect_network_interface(interfce_id = nil)
    @interface_id ||= interface_id
    response      = send_request('put', "interface/#{interface_id}/to/switch/shared",nil)
    @server_id    = response['ServerID']
    @interface_id = response['InterfaceID']

    rescue => exception
      puts exception
  end

  #パケットフィルターを適用
  def apply_packet_filter(params = nil)
    @interface_id     ||= params[:interface_id]
    @packet_filter_id ||= params[:packet_filter_id]
    response      = send_request('put', "interface/#{@interface_id}/to/packetfilter/#{@packet_filter_id}",nil)
    @server_id    = response['Interface']['Server']['ID']

    rescue => exception
      puts exception
  end

  # ディスク作成
  def create_a_disk()
    disk        = { Plan: {ID:4}, SizeMB: 20480, Name: @name, Description: @description} #plan is SSD, sizeMB is 20GB
    response    = send_request('post','disk',{Disk: disk})
    response['Disk']['ID']

    rescue => exception
      puts exception
      puts 'Can not create a disk.'
  end

  def disk_connection(disk_id)
    response = send_request('put',"disk/#{disk_id}/to/server/#{@server_id}",nil)

    rescue => exception
      puts exception
  end

  def update_startup_scripts(text)
    body = {Note:{Content:text}}
    send_request('put',"note/#{@notes[:ID]}",body)
  end

  def setup_ssh_key(disk_id)
    _put_ssh_key(disk_id)
    _copying_image()
  end

  def get_servers()
    body = { Filter: {Tags: @tags.first} }
    send_request('get','server',body) 
  end 

  def get_archives()
    send_request('get','archive',nil) 
  end

  def server_start()
    send_request('put',"server/#{@server_id}/power",nil)
  end

  def server_shutdown()
    send_request('delete',"server/#{@server_id}/power",nil)
  end

  private

  def _put_ssh_key(disk_id)
    body = { 
      SSHKey:  {
        PublicKey: [@pubkey]
      }
    }
    if !@notes.empty?
      body[:Notes] = @notes
    end
    send_request('put',"disk/#{disk_id}/config",body)
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
    response = @client.send(http_method, endpoint, query)
    if response.body.empty?
      raise "Can not send #{http_method} request."
    end
    
    if response.body['is_fatal']
      pp response.body
      raise "Can not success"
    end

    if @isDebug 
      pp response.body
    end
    response.body
  end
end
