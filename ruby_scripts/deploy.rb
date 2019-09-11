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
  #jsではproductionの方を特別にしていたが、たぶんprodocutionの方を頻繁に叩くので...
  def initialize(argv)
    if /sandbox/ =~ argv[0]
      @isSandbox = true
    end
  end

  def run()
    request_params = perform_init_params()
    p request_params
  end

  def perform_init_params
    if @isSandbox
      init_production_params()
    else
      init_sandbox_params()
    end
  end

  def init_production_params
    {
     zone: "31002", # 石狩第二
     api: "https://secure.sakura.ad.jp/cloud/zone/is1b/api/cloud/1.1/", # 石狩第二
     packetfilterid: '112900922505', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
    }
  end
  def init_sandbox_params
    {
     zone: "29001", # サンドボックス
     api: "https://secure.sakura.ad.jp/cloud/zone/tk1v/api/cloud/1.1/",
     packetfilterid: '112900927419', # See https://secure.sakura.ad.jp/cloud/iaas/#!/network/packetfilter/.
    }
  end
 
end

CoderDojoSakuraCLI.new(ARGV).run()

