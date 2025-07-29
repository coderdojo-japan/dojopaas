#!/usr/bin/env ruby

# リソースを名前で検索する汎用スクリプト
# 使い方: bundle exec ruby find_resources.rb [検索文字列]
# 例: bundle exec ruby find_resources.rb ome
#     bundle exec ruby find_resources.rb coderdojo
#     bundle exec ruby find_resources.rb （全て表示）

require_relative '../scripts/sakura_server_user_agent.rb'
require 'time'

# 環境変数のチェック
unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
  puts "Error: SACLOUD_ACCESS_TOKEN and SACLOUD_ACCESS_TOKEN_SECRET must be set"
  exit 1
end

# 検索文字列（引数がなければ全て表示）
search_term = ARGV[0] || ""

# 石狩第二ゾーンのパラメータ（本番環境）
params = {
  zone: "31002",
  zone_id: "is1b", 
  packet_filter_id: nil
}

puts "=== さくらのクラウド リソース検索 ==="
puts "検索条件: #{search_term.empty? ? '全て' : search_term}"
puts "時刻: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts ""

ssua = SakuraServerUserAgent.new(**params)

# サーバーの確認
puts "【サーバー一覧】"
servers = ssua.get_servers()['Servers']
matched_servers = servers.select { |s| s['Name'].include?(search_term) }

if matched_servers.any?
  puts "#{matched_servers.length}台のサーバーが見つかりました:"
  puts ""
  
  matched_servers.sort_by { |s| s['Name'] }.each do |server|
    created_at = Time.parse(server['CreatedAt'])
    hours_ago = ((Time.now - created_at) / 3600).round(1)
    
    puts "📦 #{server['Name']}"
    puts "  - ID: #{server['ID']}"
    puts "  - タグ: #{server['Tags'].join(', ')}"
    puts "  - 作成: #{created_at.strftime('%Y-%m-%d %H:%M')} (#{hours_ago}時間前)"
    puts "  - ステータス: #{server['Instance']['Status']}"
    puts "  - 説明: #{server['Description'][0..50]}..." if server['Description'] && server['Description'].length > 50
    puts ""
  end
else
  puts "❌ 該当するサーバーが見つかりません"
  puts ""
end

# ディスクの確認
puts "【ディスク一覧】"
disks_response = ssua.send(:send_request, 'get', 'disk', nil)
disks = disks_response['Disks'] || []
matched_disks = disks.select { |d| d['Name'].include?(search_term) }

if matched_disks.any?
  puts "#{matched_disks.length}個のディスクが見つかりました:"
  puts ""
  
  matched_disks.sort_by { |d| d['Name'] }.each do |disk|
    created_at = Time.parse(disk['CreatedAt'])
    hours_ago = ((Time.now - created_at) / 3600).round(1)
    
    puts "💾 #{disk['Name']}"
    puts "  - ID: #{disk['ID']}"
    puts "  - サイズ: #{disk['SizeMB'] / 1024} GB"
    puts "  - 作成: #{created_at.strftime('%Y-%m-%d %H:%M')} (#{hours_ago}時間前)"
    puts "  - ステータス: #{disk['Availability']}"
    puts "  - サーバー接続: #{disk['Server'] ? disk['Server']['ID'] : '未接続'}"
    puts ""
  end
else
  puts "❌ 該当するディスクが見つかりません"
  puts ""
end

puts "=== 検索完了 ==="
puts "合計: サーバー #{matched_servers.length}台, ディスク #{matched_disks.length}個"