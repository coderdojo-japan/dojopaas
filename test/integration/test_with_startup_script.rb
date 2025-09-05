#!/usr/bin/env ruby

# 修正されたsakura_server_user_agent.rbを使用したテスト
# デフォルトでSTARTUP_SCRIPT_IDが設定される

require 'dotenv/load'
require_relative '../../scripts/sakura_server_user_agent.rb'

# SSH公開鍵を読み込み
ssh_public_key_path = ENV['SSH_PUBLIC_KEY_PATH'] || File.expand_path('~/.ssh/id_rsa.pub')
unless File.exist?(ssh_public_key_path)
  puts "Error: SSH public key not found at #{ssh_public_key_path}"
  exit 1
end

pubkey = File.read(ssh_public_key_path).strip
server_name = "test-with-startup-#{Time.now.strftime('%Y%m%d%H%M%S')}"

puts "=== スタートアップスクリプト有効化テスト ==="
puts "サーバー名: #{server_name}"
puts "スタートアップスクリプトID: #{SakuraServerUserAgent::STARTUP_SCRIPT_ID}"
puts ""

begin
  # デフォルト値を使用（テスト用にパケットフィルター無効）
  ssua = SakuraServerUserAgent.new(packet_filter_id: nil)
  
  # 通常版Ubuntu 24.04を検索
  archives = ssua.get_archives()['Archives']
  ubuntu_archive = archives.find do |arch|
    /ubuntu/i =~ arch['Name'] && /24\.04/i =~ arch['Name'] && !(/cloudimg/i =~ arch['Name'])
  end
  
  if ubuntu_archive
    puts "使用するアーカイブ: #{ubuntu_archive['Name']} (ID: #{ubuntu_archive['ID']})"
    ssua.archive_id = ubuntu_archive['ID']
  else
    puts "❌ Ubuntu 24.04（通常版）が見つかりません"
    exit 1
  end
  
  puts "\n🚀 サーバー作成を開始..."
  puts "設定内容:"
  puts "  - SSH鍵: disk/config APIで設定"
  puts "  - スタートアップスクリプト: デフォルトで有効（ID: #{SakuraServerUserAgent::STARTUP_SCRIPT_ID}）"
  puts ""
  
  ssua.create(
    name: server_name,
    description: "Startup script test - DELETE ME",
    pubkey: pubkey,
    tag: 'test'
  )
  
  puts "\n✅ サーバー作成完了"
  
  # IPアドレスを取得
  servers = ssua.get_servers()['Servers']
  created_server = servers.find { |s| s['Name'] == server_name }
  
  if created_server
    ip_address = created_server['Interfaces'].first['IPAddress'] rescue 'N/A'
    puts "\n📦 作成されたサーバー:"
    puts "  - 名前: #{server_name}"
    puts "  - ID: #{created_server['ID']}"
    puts "  - IPアドレス: #{ip_address}"
    puts ""
    puts "⏰ 起動とスタートアップスクリプトの実行まで約2-3分お待ちください"
    puts ""
    puts "🔍 確認コマンド:"
    puts "  ruby test/verify_server_setup.rb #{ip_address}"
    puts ""
    puts "📝 期待される結果:"
    puts "  1. SSH接続: ✅（disk/config APIで設定）"
    puts "  2. Ansible: ✅（スタートアップスクリプトで自動インストール）"
    puts "  3. iptables: ✅（スタートアップスクリプトで自動設定）"
    puts "  4. SSH設定: ✅（スタートアップスクリプトで自動強化）"
  end
  
rescue => e
  puts "\n❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end