#!/usr/bin/env ruby

require 'dotenv/load'
require_relative '../sakura_server_user_agent.rb'

if ARGV.empty?
  puts "使い方: ruby #{$0} <サーバー名の一部>"
  puts "例: ruby #{$0} test-yasulab"
  exit 1
end

search_term = ARGV[0]

params = {
  zone: "31002",
  zone_id: "is1b", 
  packet_filter_id: nil
}

ssua = SakuraServerUserAgent.new(**params)

puts "=== サーバー詳細情報 ==="
puts "検索条件: #{search_term}"
puts ""

# サーバー情報を取得
servers = ssua.get_servers()['Servers']
target_servers = servers.select { |s| s['Name'].include?(search_term) }

if target_servers.empty?
  puts "該当するサーバーが見つかりません"
  exit 1
end

target_servers.each do |server|
  puts "="*60
  puts "📦 サーバー: #{server['Name']}"
  puts "="*60
  
  # 基本情報
  puts "ID: #{server['ID']}"
  puts "作成時刻: #{server['CreatedAt']}"
  puts "ステータス: #{server['Instance']['Status']}"
  puts "電源状態: #{server['Instance']['Status']}"
  
  # ネットワーク情報
  if server['Interfaces'] && server['Interfaces'].any?
    interface = server['Interfaces'].first
    puts "\nネットワーク情報:"
    puts "  - IPアドレス: #{interface['IPAddress']}"
    puts "  - MACアドレス: #{interface['MACAddress']}"
    puts "  - インターフェースID: #{interface['ID']}"
  else
    puts "\nネットワーク情報: なし"
  end
  
  # ディスク情報
  if server['Disks'] && server['Disks'].any?
    puts "\nディスク情報:"
    server['Disks'].each_with_index do |disk, i|
      puts "  ディスク#{i+1}:"
      puts "    - ID: #{disk['ID']}"
      puts "    - 名前: #{disk['Name']}"
      puts "    - サイズ: #{disk['SizeMB']}MB"
      puts "    - 接続: #{disk['Connection']}"
    end
  else
    puts "\nディスク情報: なし"
  end
  
  # タグ
  puts "\nタグ: #{server['Tags'].join(', ')}"
  
  # 詳細な電源状態を取得
  puts "\n詳細な電源状態を確認中..."
  begin
    power_status = ssua.send(:send_request, 'get', "server/#{server['ID']}/power", nil)
    puts "電源詳細: #{power_status.inspect}"
  rescue => e
    puts "電源状態取得エラー: #{e.message}"
  end
  
  puts "\n" + "="*60
  puts "トラブルシューティング:"
  puts "="*60
  
  if server['Instance']['Status'] == 'down'
    puts "⚠️  サーバーが停止しています"
    puts "  - さくらのクラウドコントロールパネルで確認してください"
    puts "  - 手動で起動が必要かもしれません"
  elsif interface && interface['IPAddress']
    puts "✅ サーバーは起動中でIPアドレスが割り当てられています"
    puts ""
    puts "SSH接続できない場合の確認事項:"
    puts "1. SSH鍵が正しく設定されているか"
    puts "   - 使用した公開鍵: $SSH_PUBLIC_KEY_PATH"
    puts ""
    puts "2. cloud-initの実行状態"
    puts "   - さくらのクラウドコンソールでVNCコンソールを開く"
    puts "   - ログイン画面が表示されるか確認"
    puts ""
    puts "3. ネットワーク接続"
    puts "   - ping #{interface['IPAddress']}"
    puts ""
    puts "4. SSH鍵の問題の可能性"
    puts "   - cloud-initでSSH鍵が正しく設定されなかった可能性"
    puts "   - VNCコンソールからログインして /home/ubuntu/.ssh/authorized_keys を確認"
  end
  
  puts ""
end