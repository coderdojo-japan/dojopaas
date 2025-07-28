#!/usr/bin/env ruby

# cleanup_resources.txtに記載されたリソースが削除されたか確認するスクリプト
# 注意: このスクリプトは確認のみ行い、削除は一切行いません
#
# 使い方:
#   1. テスト実行後、cleanup_resources.txtにリソースIDを記録
#   2. 手動でコントロールパネルから削除
#   3. このスクリプトで削除確認

require '../scripts/sakura_server_user_agent.rb'

# 環境変数のチェック
unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
  puts "Error: SACLOUD_ACCESS_TOKEN and SACLOUD_ACCESS_TOKEN_SECRET must be set"
  exit 1
end

# cleanup_resources.txtから確認対象のリソースIDを抽出
cleanup_file = 'cleanup_resources.txt'
unless File.exist?(cleanup_file)
  puts "cleanup_resources.txt not found"
  exit 0
end

# リソースIDを抽出
disk_ids = []
server_ids = []

File.read(cleanup_file).each_line do |line|
  if line =~ /ディスクID:\s*(\d+)/
    disk_ids << $1
  elsif line =~ /サーバーID:\s*(\d+)/
    server_ids << $1
  end
end

puts "=== クリーンアップ確認スクリプト ==="
puts "確認対象:"
puts "  ディスク: #{disk_ids.join(', ')}"
puts "  サーバー: #{server_ids.join(', ')}"
puts ""

# 石狩第二ゾーンのパラメータ
params = {
  zone: "31002",
  zone_id: "is1b",
  packet_filter_id: nil
}

ssua = SakuraServerUserAgent.new(**params)

# 既存のディスクとサーバーを取得
puts "現在のリソースを確認中..."

# サーバーの確認
if server_ids.any?
  puts "\n【サーバーの確認】"
  existing_servers = ssua.get_servers()['Servers']
  existing_server_ids = existing_servers.map { |s| s['ID'].to_s }
  
  server_ids.each do |server_id|
    if existing_server_ids.include?(server_id)
      server = existing_servers.find { |s| s['ID'].to_s == server_id }
      puts "  ❌ サーバーID #{server_id} (#{server['Name']}) はまだ存在します"
    else
      puts "  ✅ サーバーID #{server_id} は削除されています"
    end
  end
else
  puts "\n【サーバーの確認】"
  puts "  確認対象なし"
end

# ディスクの確認（APIで全ディスクを取得）
if disk_ids.any?
  puts "\n【ディスクの確認】"
  # ディスク一覧を取得するAPIエンドポイント
  disks_response = ssua.send(:send_request, 'get', 'disk', nil)
  existing_disks = disks_response['Disks'] || []
  existing_disk_ids = existing_disks.map { |d| d['ID'].to_s }
  
  disk_ids.each do |disk_id|
    if existing_disk_ids.include?(disk_id)
      disk = existing_disks.find { |d| d['ID'].to_s == disk_id }
      puts "  ❌ ディスクID #{disk_id} (#{disk['Name']}) はまだ存在します"
    else
      puts "  ✅ ディスクID #{disk_id} は削除されています"
    end
  end
else
  puts "\n【ディスクの確認】"
  puts "  確認対象なし"
end

puts "\n=== 確認完了 ==="
puts "注意: このスクリプトは確認のみ行い、削除は行いません"
puts "削除が必要な場合は、さくらのクラウドコントロールパネルから手動で削除してください"