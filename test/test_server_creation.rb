#!/usr/bin/env ruby

require '../scripts/sakura_server_user_agent.rb'

# 環境変数のチェック
unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
  puts "Error: SACLOUD_ACCESS_TOKEN and SACLOUD_ACCESS_TOKEN_SECRET must be set"
  puts "Usage:"
  puts "  export SACLOUD_ACCESS_TOKEN=your-token"
  puts "  export SACLOUD_ACCESS_TOKEN_SECRET=your-secret"
  puts "  bundle exec ruby test_server_creation.rb"
  exit 1
end

# テスト用のパラメータ（サンドボックス環境を使用）
test_params = {
  zone: "29001", # サンドボックス
  zone_id: "tk1v", # サンドボックス
  packet_filter_id: '112900927419' # サンドボックス用
}

# 実際のSSH公開鍵を使用してください
test_server_info = {
  name: "test-dojopaas-debug-#{Time.now.strftime('%Y%m%d%H%M%S')}",
  description: "Debug test server - please delete after testing",
  pubkey: ENV['TEST_SSH_PUBKEY'] || "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHvFcc9KGHNtQc debug-test",
  tag: "debug-test"
}

puts "=== Starting debug test server creation ==="
puts "This will create a test server named: #{test_server_info[:name]}"
puts "Please delete this server manually after testing"
puts ""

# SakuraServerUserAgentの初期化
ssua = SakuraServerUserAgent.new(**test_params)

# アーカイブリストの取得
puts "1. Getting archive list..."
archives = ssua.get_archives()
puts "Found #{archives['Archives'].length} archives"

# Ubuntu cloudimgを探す
archive_id = nil
archives['Archives'].each do |arch|
  puts "  - #{arch['Name']}"
  if /ubuntu/i =~ arch['Name'] && /24\.04/i =~ arch['Name'] && /cloudimg/i =~ arch['Name']
    archive_id = arch['ID']
    puts "  -> Selected: #{arch['Name']} (ID: #{archive_id})"
    break
  end
end

unless archive_id
  puts "ERROR: Could not find Ubuntu 24.04 cloudimg"
  exit 1
end

ssua.archive_id = archive_id

# サーバー作成のテスト
puts "\n2. Creating server..."
begin
  ssua.create(
    name: test_server_info[:name],
    description: test_server_info[:description],
    pubkey: test_server_info[:pubkey],
    tag: test_server_info[:tag]
  )
  puts "SUCCESS: Server creation completed!"
rescue => e
  puts "ERROR: Server creation failed"
  puts e.message
  puts e.backtrace
end