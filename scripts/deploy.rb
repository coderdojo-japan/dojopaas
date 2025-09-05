#!/usr/bin/env ruby

#  # jsのserver.createで使っているフィールドを参考
#  def initialize(zone:0, plan:nil, packetfilterid:nil, name:nil, description:nil,
#                 tags:nil, pubkey:nil, disk:{}, resolve:nil, notes:nil)
#    @zone           = zone
#    @plan           = plan
#    @packetfilterid = packetfilterid
#    @name           = name
#    @description    = description
#    @tags           = tags
#    @pubkey         = pubkey
#    @disk           = disk
#    @resolve        = resolve
#    @notes          = notes

class CoderDojoSakuraCLI
  require './scripts/sakura_server_user_agent.rb'
  require 'csv'
  INSTANCE_CSV = "servers.csv".freeze
  RESULT_INSTANCE_CSV = "instances.csv".freeze

  #jsではproductionの方を特別にしていたが、たぶんprodocutionの方を頻繁に叩くので...
  def initialize(argv)
    if /sandbox/ =~ argv[0]
      @isSandbox = true
    end
  end


  def update_startup_scripts
    startup_file_name = "./startup-scripts/112900928939"
    text = File.open(startup_file_name,'r').read
    @ssua.update_startup_scripts(text)
  end

  def run()
    request_params = perform_init_params()
    @ssua = SakuraServerUserAgent.new(**request_params)

    #update_startup_scripts() unless @isSandbox

    @ssua.archive_id = initial_archive_id()

    #serverのリストを取得
    puts 'Get a list of existing servers.'
    sakura_servers = (@ssua.get_servers())['Servers']
    sakura_server_names = []

    sakura_servers.each do |s|
      sakura_server_names.push(s['Name'])
    end

    CSV.read(INSTANCE_CSV,headers: true).each do |line|
      next if sakura_server_names.include?(line['name']) #すでに登録されているものは飛ばす
      @ssua.create(name:line['name'], description:line['description'],pubkey:line['pubkey'], tag:line['branch'])
    end

    result_csv_elements = []
    result_sakura_servers = (@ssua.get_servers())['Servers']
    result_sakura_servers.each do |s|
      result_csv_elements.push([s['Name'], s['Interfaces'].first['IPAddress'], s['Description']])
    end

    CSV.open(RESULT_INSTANCE_CSV, 'wb') do |csv|
      csv << ['Name', 'IP Address', 'Description']
      result_csv_elements.map{ |r| csv << r }
    end

    puts "the #{RESULT_INSTANCE_CSV} was saved!"
  end

  # 個別サーバー作成メソッド（Rakeタスク用）
  # DRY原則: 既存のロジックを最大限再利用
  def create_single_server(server_name)
    # 初期化パラメータとAPIクライアントのセットアップ（既存ロジック再利用）
    request_params = perform_init_params()
    @ssua = SakuraServerUserAgent.new(**request_params)
    @ssua.archive_id = initial_archive_id()

    # servers.csvから指定されたサーバー情報を取得
    server_info = nil
    CSV.read(INSTANCE_CSV, headers: true).each do |line|
      if line['name'] == server_name
        server_info = line
        break
      end
    end

    unless server_info
      puts "❌ エラー: サーバー '#{server_name}' が servers.csv に見つかりません"
      return false
    end

    # 既存サーバーのチェック
    puts '🔍 既存サーバーをチェック中...'
    sakura_servers = (@ssua.get_servers())['Servers']
    sakura_servers.each do |s|
      if s['Name'] == server_name
        puts "⚠️  警告: サーバー '#{server_name}' は既に存在します"
        puts "  IPアドレス: #{s['Interfaces'].first['IPAddress']}"
        puts "  説明: #{s['Description']}"
        return false
      end
    end

    # サーバー作成（既存のcreateメソッドを再利用）
    puts "🚀 サーバー '#{server_name}' を作成中..."
    puts "  説明: #{server_info['description']}"
    puts "  ブランチ: #{server_info['branch']}"
    
    begin
      @ssua.create(
        name: server_info['name'],
        description: server_info['description'],
        pubkey: server_info['pubkey'],
        tag: server_info['branch']
      )
      
      # 作成結果の確認
      sleep(5)  # APIの反映待ち
      result_servers = (@ssua.get_servers())['Servers']
      created_server = result_servers.find { |s| s['Name'] == server_name }
      
      if created_server
        puts "✅ サーバー作成成功!"
        puts "  サーバー名: #{created_server['Name']}"
        puts "  IPアドレス: #{created_server['Interfaces'].first['IPAddress']}"
        puts "  説明: #{created_server['Description']}"
        return true
      else
        puts "❌ サーバー作成に失敗した可能性があります"
        return false
      end
    rescue => e
      puts "❌ エラー: #{e.message}"
      return false
    end
  end


  private

  def perform_init_params
    if @isSandbox
      {
       zone: "29001", # サンドボックス
       zone_id: "tk1v",
       packet_filter_id: '112900927419', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
       verbose: ENV['VERBOSE'] == 'true'  # デバッグモード
      }
    else
      {
       zone: "31002", # 石狩第二
       zone_id: "is1b", # 石狩第二
       packet_filter_id: '112900922505', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
       verbose: ENV['VERBOSE'] == 'true'  # デバッグモード
      }
    end
  end

  def initial_archive_id
    archiveid = nil
    selected_name = nil
    archives = @ssua.get_archives()
    puts "List of Archives:"
    archives['Archives'].each do |arch|
      # MEMO: Ubuntuの対象バージョンの提供が終了した場合は、バージョンを上げる
      # https://manual.sakura.ad.jp/cloud/server/os-packages/archive-iso/list.html
      puts "- Name: #{arch['Name']}"
      # 通常版Ubuntu 24.04を使用（disk/config APIでSSH鍵設定、@notesでスタートアップスクリプト実行）
      # "Ubuntu Server"で始まるものだけを対象にして、CData Syncなどを除外
      if /^Ubuntu Server/i =~ arch['Name'] && /24\.04/i =~ arch['Name'] && !(/cloudimg/i =~ arch['Name']) then
        archiveid = arch['ID']
        selected_name = arch['Name']
        break  # 最初にマッチしたものを使用
      end
    end

    if archiveid then
      puts "Selected Archive: #{selected_name}"
      puts "Archive ID: #{archiveid}"
    else
      puts "Can't get archive id"
      exit
    end
    archiveid
  end
end

CoderDojoSakuraCLI.new(ARGV).run()
