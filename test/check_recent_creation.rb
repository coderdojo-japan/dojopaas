#!/usr/bin/env ruby

# 最近作成されたサーバー/ディスクを確認するスクリプト
# 注意: このスクリプトは読み取り専用で、作成や削除は一切行いません

require '../scripts/sakura_server_user_agent.rb'
require 'time'

# 環境変数のチェック
unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
  puts "Error: SACLOUD_ACCESS_TOKEN and SACLOUD_ACCESS_TOKEN_SECRET must be set"
  exit 1
end

# 石狩第二ゾーンのパラメータ（本番環境）
params = {
  zone: "31002",
  zone_id: "is1b", 
  packet_filter_id: nil
}

puts "=== 最近作成されたリソースの確認 ==="
puts "対象: coderdojo-ome"
puts "時刻: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts ""

ssua = SakuraServerUserAgent.new(**params)

# サーバーの確認
puts "【サーバーの確認】"
servers = ssua.get_servers()['Servers']
ome_servers = servers.select { |s| s['Name'] == 'coderdojo-ome' }

if ome_servers.any?
  ome_servers.each do |server|
    created_at = Time.parse(server['CreatedAt'])
    puts "✅ サーバーが見つかりました:"
    puts "  - ID: #{server['ID']}"
    puts "  - 名前: #{server['Name']}"
    puts "  - 説明: #{server['Description']}"
    puts "  - タグ: #{server['Tags'].join(', ')}"
    puts "  - 作成日時: #{created_at.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  - ステータス: #{server['Instance']['Status']}"
    
    # 最近作成されたかチェック（24時間以内）
    if (Time.now - created_at) < 86400
      puts "  ⭐ 24時間以内に作成されました！"
    end
  end
else
  puts "❌ coderdojo-ome サーバーが見つかりません"
end

# ディスクの確認
puts "\n【ディスクの確認】"
disks_response = ssua.send(:send_request, 'get', 'disk', nil)
disks = disks_response['Disks'] || []
ome_disks = disks.select { |d| d['Name'] == 'coderdojo-ome' }

if ome_disks.any?
  ome_disks.each do |disk|
    created_at = Time.parse(disk['CreatedAt'])
    puts "✅ ディスクが見つかりました:"
    puts "  - ID: #{disk['ID']}"
    puts "  - 名前: #{disk['Name']}"
    puts "  - 説明: #{disk['Description']}"
    puts "  - サイズ: #{disk['SizeMB'] / 1024} GB"
    puts "  - 作成日時: #{created_at.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  - ステータス: #{disk['Availability']}"
    
    # 最近作成されたかチェック（24時間以内）
    if (Time.now - created_at) < 86400
      puts "  ⭐ 24時間以内に作成されました！"
    end
    
    # サーバー接続状態
    if disk['Server']
      puts "  - 接続サーバーID: #{disk['Server']['ID']}"
    else
      puts "  - サーバー未接続"
    end
  end
else
  puts "❌ coderdojo-ome ディスクが見つかりません"
end

puts "\n=== 確認完了 ==="
puts "注意: このスクリプトは確認のみ行い、作成や削除は一切行いません"