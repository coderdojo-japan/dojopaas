#!/usr/bin/env ruby
class SakuraServerUserAgent
  require 'jsonclient'
  require 'base64'
  SAKURA_BASE_URL     = 'https://secure.sakura.ad.jp/cloud/zone'
  SAKURA_CLOUD_SUFFIX = 'api/cloud'
  SAKURA_API_VERSION  = '1.1'

  SAKURA_TOKEN        = ENV.fetch('SACLOUD_ACCESS_TOKEN')
  SAKURA_TOKEN_SECRET = ENV.fetch('SACLOUD_ACCESS_TOKEN_SECRET')

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
    # スタートアップスクリプトID: 112900928939 が404エラーになるため一時的に無効化
    # 本番環境の正しいIDを確認する必要あり
    # スクリプト内容: iptables設定、SSH強化、Ansible導入
    @notes            = []
    @sakura_zone_id   = zone_id
    @archive_id       = nil

    @client = JSONClient.new
    @client.set_auth(create_endpoint(nil),SAKURA_TOKEN, SAKURA_TOKEN_SECRET)
    @client.connect_timeout = 300
    @client.send_timeout    = 300
    @client.receive_timeout = 300
  end

  def archive_id=(aid)
    @archive_id = aid
  end

  # server.createに対応
  # 引数があると、オブジェクトの状態を変えつつそちらを使う
  def create(params)
    @name        = params[:name] || @name
    @description = params[:description] || @description
    @pubkey      = params[:pubkey] || @pubkey
    @tags        = ['dojopaas',params[:tag]]

    puts "DEBUG: Creating server with name: #{@name}, description: #{@description}"
    puts "DEBUG: Tags: #{@tags.inspect}"
    puts "DEBUG: Public key: #{@pubkey[0..50]}..." if @pubkey

    puts 'create_server_instance'
    create_server_instance()

    puts 'create_network_interface'
    create_network_interface()

    puts 'connect_network_interface'
    connect_network_interface()

    puts 'apply_packet_filter'
    apply_packet_filter()

    puts 'create_a_disk'
    disk_id = create_a_disk()

    puts 'migrating_disk'

    disk_availability_flag = false
    while !disk_availability_flag
      disk_satus =  get_disk_status(disk_id)
      if /migrating/ !~  disk_satus['Disk']['Availability']
        disk_availability_flag = true
      end
      sleep(5)
    end

    puts 'disk_connection'
    disk_connection(disk_id)

    puts 'setup_ssh_key'
    setup_ssh_key(disk_id)

    puts 'server_shutdown'
    status = false
    while !status
     sleep(5)
     api_status = get_server_power_status()
     if /down/ !~ api_status['Instance']['Status']
       status = true
     end
     p api_status['Instance']['Status']
    end

    p '---------------------'
    puts 'wait_shutdown'
    status = false
    counter = 0
    while !status
     counter += 1
     sleep(5)
     api_status = get_server_power_status()
     if /down/ =~ api_status['Instance']['Status']
       status = true
     end
     if counter %5 == 0
       server_shutdown()
     end
     p api_status['Instance']['Status']
    end
    puts 'server_start'
    server_start()
  end


  # createとdestroyで独自に引数を取れるようにしておく

  #インスタンス作成
  def create_server_instance()
    puts "Create a server for #{@name}."
    query = {
      Server:  {
        ServerPlan:   {
          CPU: 1,
          MemoryMB: 1024,
          Generation: 100
        },
        Name:         @name,
        Description:  @description,
        Tags:         @tags
      }
    }
    puts "DEBUG: Server creation request: #{query.inspect}"
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
    response      = send_request('put', "interface/#{@interface_id}/to/switch/shared",nil)
    @server_id    = response['Interface']['Server']['ID']
    @interface_id = response['Interface']['ID']

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
    disk = { Plan: {ID:4}, SizeMB: 20480, Name: @name, Description: @description, SourceArchive: { ID: @archive_id }} #plan is SSD, sizeMB is 20GB
    
    # cloud-init用のスタートアップスクリプトを読み込む
    startup_script_path = './startup-scripts/112900928939'
    if File.exist?(startup_script_path)
      startup_script_content = File.read(startup_script_path)
      
      # cloud-init設定
      config = {
        UserData: Base64.strict_encode64(startup_script_content),
        SSHKeys: [ @pubkey ]
      }
      
      response = send_request('post','disk',{Disk: disk, Config: config})
    else
      puts "Warning: Startup script not found at #{startup_script_path}"
      response = send_request('post','disk',{Disk: disk})
    end
    
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
    send_request('put',"note/#{@notes.first[:ID]}",body)
  end

  def setup_ssh_key(disk_id)
    # cloud-init版では、SSH鍵はディスク作成時に設定済みなので
    # ディスクが完全に利用可能になるまで待機
    DISK_CHECK_INTERVAL = 10  # 秒
    MAX_ATTEMPTS = 30  # 10秒 x 30 = 5分
    attempts = 0
    
    puts "DEBUG: Waiting for disk to become available..."
    
    while attempts < MAX_ATTEMPTS
      disk_status = get_disk_status(disk_id)
      availability = disk_status['Disk']['Availability']
      
      puts "DEBUG: Disk availability: #{availability} (attempt #{attempts + 1}/#{MAX_ATTEMPTS})"
      
      case availability
      when 'available'
        puts "Disk is ready!"
        break
      when 'failed'
        raise "Disk creation failed with status: #{availability}"
      when 'migrating', 'creating', 'copying'
        # まだ処理中なので待機
      else
        puts "DEBUG: Unknown disk availability status: #{availability}"
      end
      
      attempts += 1
      sleep(DISK_CHECK_INTERVAL)
    end
    
    if attempts >= MAX_ATTEMPTS
      raise "Timeout waiting for disk to become available (waited #{MAX_ATTEMPTS * DISK_CHECK_INTERVAL} seconds)"
    end
    
    # サーバーを起動
    _copying_image()
  end

  def get_servers()
    body = { Filter: {Tags: @tags.first} }
    send_request('get','server',body)
  end

  def get_server_power_status
    send_request('get',"server/#{@server_id}/power",nil)
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

  def get_disk_status(disk_id)
    send_request('get',"disk/#{disk_id}",nil)
  end

  private

  def _put_ssh_key(disk_id)
    body = {
      SSHKey:  {
        PublicKey: @pubkey
      },
      Notes: @notes
    }
    send_request('put',"disk/#{disk_id}/config",body)
  end

  def _copying_image
    send_request('put',"server/#{@server_id}/power",nil)

    rescue => exception
      puts exception
  end

  def remove_instance
    # 自動削除は行わず、手動削除を促す
    puts "\n" + "="*60
    puts "ERROR: サーバー作成中にエラーが発生しました"
    if @server_id
      puts "部分的に作成されたサーバーがある可能性があります:"
      puts "  Server ID: #{@server_id}"
      puts "  Server Name: #{@name}"
      puts ""
      puts "手動で確認・削除してください:"
      puts "  1. さくらのクラウドコントロールパネルで確認"
      puts "  2. 必要に応じて手動で削除"
    else
      puts "サーバーは作成されていません（IDが設定されていません）"
    end
    puts "="*60 + "\n"
  end

  # URI(エンドポイント)を作成する
  def create_endpoint(path)
    "#{SAKURA_BASE_URL}/#{@sakura_zone_id}/#{SAKURA_CLOUD_SUFFIX}/#{SAKURA_API_VERSION}/#{path}"
  end

  # 実際に送信する
  def send_request(http_method,path,query)
    endpoint = create_endpoint(path)
    puts "DEBUG: #{http_method.upcase} #{endpoint}"
    puts "DEBUG: Request body: #{query.inspect}" if query
    response = @client.send(http_method, endpoint, query)
    if response.body.empty?
      raise "Can not send #{http_method} request."
    end

    if response.body['is_fatal']
      puts "DEBUG: Error at endpoint: #{endpoint}"
      pp response.body
      remove_instance()  # 削除はせず、手動削除の案内のみ表示
      raise "Can not success"
    end

    response.body
  end
end
