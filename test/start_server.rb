#!/usr/bin/env ruby

# サーバーを起動するスクリプト

require 'dotenv/load'
require_relative '../scripts/sakura_server_user_agent.rb'

if ARGV.empty?
  puts "使い方: ruby #{$0} <サーバーID>"
  exit 1
end

server_id = ARGV[0]

params = {
  zone: "31002",
  zone_id: "is1b",
  packet_filter_id: nil
}

ssua = SakuraServerUserAgent.new(**params)

puts "サーバー #{server_id} を起動中..."

begin
  response = ssua.send(:send_request, 'put', "server/#{server_id}/power", nil)
  puts "✅ 起動コマンドを送信しました"
  
  # 起動を待つ
  puts "起動中..."
  attempts = 0
  while attempts < 30  # 最大5分待つ
    sleep(10)
    status_response = ssua.send(:send_request, 'get', "server/#{server_id}/power", nil)
    status = status_response['Instance']['Status']
    
    puts "ステータス: #{status}"
    
    if status == 'up'
      puts "✅ サーバーが起動しました！"
      break
    end
    
    attempts += 1
  end
  
  if attempts >= 30
    puts "⚠️  タイムアウト: サーバーの起動に時間がかかっています"
  end
  
rescue => e
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end