#!/usr/bin/env ruby

# 本番環境と同じパケットフィルター設定でテスト
# 通常版Ubuntu 24.04 + disk/config API + @notes + パケットフィルター

require 'dotenv/load'
require_relative '../../scripts/sakura_server_user_agent.rb'

# SSH公開鍵を読み込み
ssh_public_key_path = ENV['SSH_PUBLIC_KEY_PATH'] || File.expand_path('~/.ssh/id_rsa.pub')
unless File.exist?(ssh_public_key_path)
  puts "Error: SSH public key not found at #{ssh_public_key_path}"
  exit 1
end

pubkey = File.read(ssh_public_key_path).strip
server_name = "test-with-pf-#{Time.now.strftime('%Y%m%d%H%M%S')}"

puts "=== 本番環境設定テスト（パケットフィルター有効） ==="
puts "サーバー名: #{server_name}"
puts ""

puts "📋 設定内容:"
puts "  - ゾーン: 石狩第二 (is1b)"
puts "  - パケットフィルターID: 112900922505"
puts "  - スタートアップスクリプトID: #{SakuraServerUserAgent::STARTUP_SCRIPT_ID}"
puts ""

begin
  # デフォルト値を使用（パケットフィルター含む）
  ssua = SakuraServerUserAgent.new
  
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
  puts "セキュリティ設定:"
  puts "  1. パケットフィルター（ネットワークレベル）"
  puts "  2. iptables（ホストレベル）"
  puts "  3. SSH鍵認証のみ（パスワード認証無効）"
  puts ""
  
  ssua.create(
    name: server_name,
    description: "Production config test - DELETE ME",
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
    puts "⏰ 起動まで約1-2分お待ちください"
    puts ""
    puts "🔍 確認コマンド:"
    puts "  ruby test/verify_server_setup.rb #{ip_address}"
    puts ""
    puts "📝 期待される結果（本番環境と同等）:"
    puts "  1. SSH接続: ✅"
    puts "  2. Ansible: ✅"
    puts "  3. iptables: ✅"
    puts "  4. SSH設定: ✅"
    puts "  5. パケットフィルター: ✅（さくらのクラウド側）"
  end
  
rescue => e
  puts "\n❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end