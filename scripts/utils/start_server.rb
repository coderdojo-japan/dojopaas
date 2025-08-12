#!/usr/bin/env ruby

# サーバーを起動するスクリプト

require 'dotenv/load'
require_relative '../sakura_server_user_agent.rb'
require_relative '../smart_wait_helper'

include SmartWaitHelper

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
  
  # スマートウェイトで起動を待つ
  puts "起動を待機中..."
  
  begin
    result = wait_for_resource("server startup", -> {
      status_response = ssua.send(:send_request, 'get', "server/#{server_id}/power", nil)
      status = status_response['Instance']['Status']
      
      {
        state: status,
        ready: status == 'up',
        error: nil,
        data: status_response
      }
    }, max_wait_time: 300, initial_interval: 2, max_interval: 20)
    
    puts "✅ サーバーが起動しました！"
    
    # サーバー情報を表示
    server_info = ssua.send(:send_request, 'get', "server/#{server_id}", nil)
    if server_info['Server']['Interfaces'] && server_info['Server']['Interfaces'].any?
      ip = server_info['Server']['Interfaces'].first['IPAddress']
      puts "IPアドレス: #{ip}"
      puts ""
      puts "SSH接続: ssh ubuntu@#{ip}"
    end
    
  rescue => e
    puts "⚠️  #{e.message}"
  end
  
rescue => e
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end