#!/usr/bin/env ruby

require 'dotenv/load'
require_relative '../sakura_server_user_agent.rb'

# パケットフィルターAPIにアクセスするための拡張クラス
class PacketFilterChecker < SakuraServerUserAgent
  def get_packet_filter(id)
    send_request('get', "packetfilter/#{id}", nil)
  end
  
  def list_packet_filters
    send_request('get', 'packetfilter', nil)
  end
end

puts "=== パケットフィルター情報確認 ==="
puts ""

checker = PacketFilterChecker.new

# デフォルトのパケットフィルターIDを確認
default_id = '112900922505'
puts "📋 デフォルトパケットフィルター ID: #{default_id}"
puts ""

begin
  # 特定のパケットフィルター詳細を取得
  puts "詳細情報を取得中..."
  filter_info = checker.get_packet_filter(default_id)
  
  if filter_info && filter_info['PacketFilter']
    pf = filter_info['PacketFilter']
    puts "名前: #{pf['Name']}"
    puts "説明: #{pf['Description']}"
    puts ""
    
    if pf['Expression'] && pf['Expression'].any?
      puts "📝 ルール一覧:"
      pf['Expression'].each_with_index do |rule, i|
        puts "  ルール#{i+1}:"
        puts "    - プロトコル: #{rule['Protocol']}"
        puts "    - 送信元: #{rule['SourceNetwork'] || 'any'}"
        puts "    - 送信元ポート: #{rule['SourcePort'] || 'any'}"
        puts "    - 宛先ポート: #{rule['DestinationPort'] || 'any'}"
        puts "    - アクション: #{rule['Action']}"
        puts "    - 説明: #{rule['Description']}" if rule['Description']
        puts ""
      end
    end
  else
    puts "❌ パケットフィルター情報を取得できませんでした"
  end
  
  # 利用可能なパケットフィルター一覧
  puts "\n=== 利用可能なパケットフィルター一覧 ==="
  all_filters = checker.list_packet_filters
  if all_filters && all_filters['PacketFilters']
    all_filters['PacketFilters'].each do |pf|
      puts "- ID: #{pf['ID']} / 名前: #{pf['Name']}"
    end
  end
  
rescue => e
  puts "エラー: #{e.message}"
  puts e.backtrace if ENV['DEBUG']
end