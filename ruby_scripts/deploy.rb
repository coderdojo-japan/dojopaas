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
    pp @isSandbox
  end
end

CoderDojoSakuraCLI.new(ARGV).run()

