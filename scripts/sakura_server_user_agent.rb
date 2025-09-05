#!/usr/bin/env ruby
require_relative 'smart_wait_helper'
require 'ipaddr'  # IP検証用

class SakuraServerUserAgent
  include SmartWaitHelper
  
  require 'jsonclient'
  require 'base64'
  SAKURA_BASE_URL     = 'https://secure.sakura.ad.jp/cloud/zone'
  SAKURA_CLOUD_SUFFIX = 'api/cloud'
  SAKURA_API_VERSION  = '1.1'

  SAKURA_TOKEN        = ENV.fetch('SACLOUD_ACCESS_TOKEN', 'dummy-token-for-test')
  SAKURA_TOKEN_SECRET = ENV.fetch('SACLOUD_ACCESS_TOKEN_SECRET', 'dummy-secret-for-test')
  
  # ディスク状態確認用の定数
  DISK_CHECK_INTERVAL = 10  # 秒
  MAX_ATTEMPTS = 30  # 10秒 x 30 = 5分
  
  # 標準スタートアップスクリプトID
  # dojopaas-default (2017年から使用)
  # 内容: iptables設定、SSH強化、Ansible導入
  STARTUP_SCRIPT_ID = 112900928939
  
  # サーバー一覧URL（最新の実サーバー情報）
  # gh-pagesブランチで公開される実際のサーバー情報
  INSTANCES_CSV_URL = "https://raw.githubusercontent.com/coderdojo-japan/dojopaas/refs/heads/gh-pages/instances.csv"

  # IPアドレス検証用のクラスメソッド（共通化）
  # @param ip [String] 検証するIPアドレス
  # @return [Boolean] 有効なIPアドレスの場合true、無効な場合false
  def self.valid_ip_address?(ip)
    return false if ip.nil? || ip.empty?
    
    begin
      IPAddr.new(ip)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
  end
  
  # IPアドレスを正規化して返す
  # @param ip [String] 正規化するIPアドレス
  # @return [String, nil] 正規化されたIPアドレス、無効な場合はnil
  def self.normalize_ip_address(ip)
    return nil if ip.nil? || ip.empty?
    
    begin
      IPAddr.new(ip).to_s
    rescue IPAddr::InvalidAddressError
      nil
    end
  end

  # jsのserver.createで使っているフィールドを参考
  # デフォルト値を本番環境（石狩第二）に設定
  def initialize(zone:"31002", packet_filter_id:'112900922505', name:nil, description:nil, zone_id:"is1b",
                 tags:nil, pubkey:nil, resolve:nil, verbose:false, notes:nil)
    @zone             = zone
    @packet_filter_id = packet_filter_id
    @name             = name
    @description      = description
    @tags             = tags || ['dojopaas']
    @pubkey           = pubkey
    @resolve          = resolve
    @plan             = 1001 # 1core 1Gb memory
    # 標準スタートアップスクリプトを使用（デフォルト値または指定値）
    @notes            = notes || [{ID: STARTUP_SCRIPT_ID}]
    @sakura_zone_id   = zone_id
    @archive_id       = nil
    @verbose          = verbose

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

    puts "DEBUG: Creating server with name: #{@name}, description: #{@description}" if @verbose
    puts "DEBUG: Tags: #{@tags.inspect}" if @verbose
    puts "DEBUG: Public key: #{@pubkey[0..50]}..." if @pubkey && @verbose

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
     p api_status['Instance']['Status'] if @verbose
    end

    p '---------------------' if @verbose
    puts 'wait_shutdown'
    
    # スマートウェイトでシャットダウンを待つ
    begin
      wait_for_server_power('down', phase: 'shutdown', max_wait_time: 120, initial_interval: 2, max_interval: 10)
    rescue => e
      # タイムアウトした場合は再度シャットダウンを試みる
      puts "Shutdown timeout, trying again..."
      server_shutdown()
      wait_for_server_power('down', phase: 'shutdown-retry', max_wait_time: 60)
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
    puts "DEBUG: Server creation request: #{query.inspect}" if @verbose
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
  def connect_network_interface(interface_id = nil)
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
    
    # パケットフィルターIDが指定されていない場合はスキップ
    if @packet_filter_id.nil?
      puts "パケットフィルターは適用されません（packet_filter_id is nil）"
      return
    end
    
    response      = send_request('put', "interface/#{@interface_id}/to/packetfilter/#{@packet_filter_id}",nil)
    @server_id    = response['Interface']['Server']['ID']

    rescue => exception
      puts exception
  end

  # ディスク作成
  def create_a_disk()
    disk = {
      Plan: {ID:4},
      SizeMB: 20480,
      Name: @name,
      Description: @description,
      SourceArchive: { ID: @archive_id }
    } #plan is SSD, sizeMB is 20GB
    
    response = send_request('post','disk',{Disk: disk})
    
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
    # スマートウェイト実装：ディスクが完全にavailableになるまで待機
    wait_for_disk_available(disk_id, phase: "creation", max_wait_time: 300)
    
    # SSH鍵を設定
    _put_ssh_key(disk_id)
    
    # SSH鍵設定後、再度ディスクがavailableになるまで待機（通常より短い時間）
    wait_for_disk_available(disk_id, phase: "ssh-key-setup", max_wait_time: 60, initial_interval: 1, max_interval: 8)
    
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
  
  # サーバーの詳細情報を取得（ディスク情報を含む）
  def get_server_details(server_id)
    send_request('get',"server/#{server_id}",nil)
  end
  
  # ディスク詳細情報を取得
  def get_disk_details(disk_id)
    send_request('get',"disk/#{disk_id}",nil)
  end
  
  # サーバーを削除（ディスクも同時削除可能）
  def delete_server(server_id, disk_ids = [])
    delete_params = disk_ids.any? ? { WithDisk: disk_ids } : {}
    send_request('delete',"server/#{server_id}", delete_params)
  end
  
  # 特定サーバーの電源状態を取得
  def get_server_power_status_by_id(server_id)
    send_request('get',"server/#{server_id}/power",nil)
  end
  
  # 特定サーバーを停止
  def stop_server(server_id)
    send_request('delete',"server/#{server_id}/power",nil)
  end

  private

  def _put_ssh_key(disk_id)
    # disk/config APIを使用してSSH鍵を設定
    body = {
      SSHKey: {
        PublicKey: @pubkey
      },
      Notes: @notes
    }
    puts "DEBUG: Setting SSH key via disk/config API" if @verbose
    send_request('put',"disk/#{disk_id}/config",body)
  end

  def _copying_image
    # SSH鍵はdisk/config APIで設定済み
    # スタートアップスクリプトはサーバー起動時に指定する必要がある
    
    puts "DEBUG: Starting server with startup script ID: #{@notes.first[:ID]}" if @verbose
    
    # サーバー起動時にスタートアップスクリプトIDを指定
    body = {
      Notes: @notes
    }
    send_request('put',"server/#{@server_id}/power", body)

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
    puts "DEBUG: #{http_method.upcase} #{endpoint}" if @verbose
    puts "DEBUG: Request body: #{query.inspect}" if query && @verbose
    response = @client.send(http_method, endpoint, query)
    if response.body.empty?
      raise "Can not send #{http_method} request."
    end

    if response.body['is_fatal']
      puts "DEBUG: Error at endpoint: #{endpoint}" if @verbose
      pp response.body
      remove_instance()  # 削除はせず、手動削除の案内のみ表示
      raise "Can not success"
    end

    response.body
  end
end
