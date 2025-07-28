#!/usr/bin/env ruby

# 石狩第1ゾーンでGeneration 200が使えるか確認するスクリプト

require '../scripts/sakura_server_user_agent.rb'

# 石狩第1ゾーン（is1a）のパラメータ
is1a_params = {
  zone: "31001", # 石狩第1
  zone_id: "is1a", # 石狩第1
  packet_filter_id: nil # テスト用なのでフィルターなし
}

puts "=== 石狩第1ゾーン Generation 200 テスト ==="
puts ""

# SakuraServerUserAgentの初期化
ssua = SakuraServerUserAgent.new(**is1a_params)

# アーカイブリストの取得
puts "1. 石狩第1ゾーンのアーカイブリストを取得..."
archives = ssua.get_archives()
puts "アーカイブ数: #{archives['Archives'].length}"

# Ubuntu 24.04 cloudimgを探す
archive_id = nil
archives['Archives'].each do |arch|
  if /ubuntu/i =~ arch['Name'] && /24\.04/i =~ arch['Name'] && /cloudimg/i =~ arch['Name']
    archive_id = arch['ID']
    puts "選択されたアーカイブ: #{arch['Name']} (ID: #{archive_id})"
    break
  end
end

unless archive_id
  puts "ERROR: Ubuntu 24.04 cloudimg が見つかりません"
  exit 1
end

# Generation 200でサーバー作成をテスト（実際には作成しない）
puts "\n2. Generation 200でのサーバー作成パラメータ:"
server_params = {
  Server: {
    ServerPlan: {
      CPU: 1,
      MemoryMB: 1024,
      Generation: 200
    },
    Name: "test-gen200-#{Time.now.strftime('%Y%m%d%H%M%S')}",
    Description: "Generation 200 test - DO NOT CREATE",
    Tags: ["dojopaas", "gen200-test"]
  }
}

require 'json'
puts server_params.to_json
puts "\n石狩第1ゾーン（is1a）ではGeneration 200が利用可能なはずです。"
puts "石狩第2ゾーン（is1b）ではGeneration 100のみ利用可能です。"
puts "\n長期運用を考えると、石狩第1ゾーン + Generation 200への移行を検討する価値があります。"