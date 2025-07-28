#!/usr/bin/env ruby

# CIと同じ環境をローカルでシミュレートするテストスクリプト

require '../scripts/sakura_server_user_agent.rb'
require 'csv'

# 環境変数のチェック
unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
  puts "Error: SACLOUD_ACCESS_TOKEN and SACLOUD_ACCESS_TOKEN_SECRET must be set"
  puts "Usage:"
  puts "  export SACLOUD_ACCESS_TOKEN=your-token"
  puts "  export SACLOUD_ACCESS_TOKEN_SECRET=your-secret"
  puts "  bundle exec ruby test_ci_simulation.rb"
  exit 1
end

puts "=== CI環境シミュレーションテスト ==="
puts "本番と同じ設定でテストサーバーを作成します"
puts ""

# CIと同じパラメータ（本番環境）
production_params = {
  zone: "31002", # 石狩第二
  zone_id: "is1b", # 石狩第二  
  packet_filter_id: '112900922505' # 本番用
}

# テスト用のCSVデータを作成
test_csv_file = 'test_servers.csv'
File.open(test_csv_file, 'w') do |csv|
  csv.puts "name,branch,description,pubkey"
  csv.puts "test-ci-sim-#{Time.now.strftime('%Y%m%d%H%M%S')},test-branch,CI simulation test - DELETE ME,ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHvFcc9KGHNtQc test-key"
end

puts "1. SakuraServerUserAgentを初期化（本番パラメータ使用）"
ssua = SakuraServerUserAgent.new(**production_params)

puts "\n2. アーカイブリストを取得"
archives = ssua.get_archives()
puts "アーカイブ数: #{archives['Archives'].length}"

# Ubuntu 24.04 cloudimgを探す（CIと同じ）
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
  File.delete(test_csv_file)
  exit 1
end

ssua.archive_id = archive_id

puts "\n3. 既存サーバーリストを取得"
existing_servers = (ssua.get_servers())['Servers']
existing_server_names = existing_servers.map { |s| s['Name'] }
puts "既存サーバー数: #{existing_server_names.length}"

puts "\n4. テストサーバーを作成"
begin
  CSV.read(test_csv_file, headers: true).each do |line|
    if existing_server_names.include?(line['name'])
      puts "スキップ: #{line['name']} は既に存在します"
      next
    end
    
    puts "\n作成中: #{line['name']}"
    ssua.create(
      name: line['name'],
      description: line['description'],
      pubkey: line['pubkey'],
      tag: line['branch']
    )
    
    puts "成功: サーバー作成が完了しました！"
  end
rescue => e
  puts "\nERROR: サーバー作成に失敗しました"
  puts "エラーメッセージ: #{e.message}"
  puts "\nスタックトレース:"
  puts e.backtrace.join("\n")
ensure
  # テストCSVファイルを削除
  File.delete(test_csv_file) if File.exist?(test_csv_file)
end

puts "\n=== テスト完了 ==="
puts "作成されたテストサーバーは手動で削除してください"