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

    update_startup_scripts() unless @isSandbox
  end


  private

  def perform_init_params
    if @isSandbox
      {
       zone: "31002", # 石狩第二
       zone_id: "is1b", # 石狩第二
       packetfilterid: '112900922505', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
      }
    else 
      {
       zone: "29001", # サンドボックス
       zone_id: "tk1v",
       packetfilterid: '112900927419', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
      }
    end
  end
end

CoderDojoSakuraCLI.new(ARGV).run()

