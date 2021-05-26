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
  require './ruby_scripts/sakura_server_user_agent.rb'
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
    @ssua = SakuraServerUserAgent.new(request_params)

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


  private

  def perform_init_params
    if @isSandbox
      {
       zone: "29001", # サンドボックス
       zone_id: "tk1v",
       packet_filter_id: '112900927419', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
      }
    else
      {
       zone: "31002", # 石狩第二
       zone_id: "is1b", # 石狩第二
       packet_filter_id: '112900922505', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
      }
    end
  end

  def initial_archive_id
    archiveid = nil
    archives = @ssua.get_archives()
    puts "List of Archives:"
    archives['Archives'].each do |arch|
      # MEMO: Ubuntuの対象バージョンの提供が終了した場合は、バージョンを上げる
      puts "- Name: #{arch['Name']}"
      if /ubuntu/i =~ arch['Name'] && /20\.04/i =~ arch['Name'] then
        archiveid = arch['ID']
      end
    end

    if archiveid then
      puts "Archive ID: #{archiveid}"
    else
      puts "Can't get archive id"
      exit
    end
    archiveid
  end
end

CoderDojoSakuraCLI.new(ARGV).run()
