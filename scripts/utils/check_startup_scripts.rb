#!/usr/bin/env ruby

# 利用可能なスタートアップスクリプト（Noteリソース）を調査

require 'dotenv/load'
require_relative '../sakura_server_user_agent.rb'

puts "=== スタートアップスクリプト（Note）一覧 ==="
puts "時刻: #{Time.now}"
puts ""

begin
  # 拡張クラスでpublicメソッドとしてアクセス
  class StartupScriptChecker < SakuraServerUserAgent
    def get_notes
      send_request('get', 'note', {})
    end
  end
  
  # デフォルト値を使用（石狩第二ゾーン）
  ssua = StartupScriptChecker.new
  
  # Noteリソースの一覧を取得
  response = ssua.get_notes()
  
  if response && response['Notes']
    notes = response['Notes']
    
    # シェルスクリプトタイプのNoteのみフィルタ
    shell_notes = notes.select { |n| n['Class'] == 'shell' }
    
    puts "📝 シェルスクリプトタイプのNote: #{shell_notes.length}件"
    puts ""
    
    # 作成日時でソート（新しい順）
    shell_notes.sort_by { |n| n['CreatedAt'] }.reverse.each_with_index do |note, index|
      puts "#{index + 1}. #{note['Name']}"
      puts "   ID: #{note['ID']}"
      puts "   作成: #{note['CreatedAt']}"
      puts "   更新: #{note['ModifiedAt']}"
      
      # スクリプト内容の最初の数行を表示
      if note['Content']
        lines = note['Content'].split("\n")[0..2]
        puts "   内容:"
        lines.each { |line| puts "     #{line}" }
        puts "     ..." if note['Content'].split("\n").length > 3
      end
      
      puts ""
    end
    
    # 特定のIDを検索
    target_id = "112900928939"
    if notes.any? { |n| n['ID'] == target_id }
      puts "✅ ID #{target_id} は存在します"
    else
      puts "❌ ID #{target_id} は見つかりません"
    end
    
    # DojoPaaSという名前を含むNoteを検索
    dojopaas_notes = notes.select { |n| n['Name'] =~ /DojoPaaS/i }
    if dojopaas_notes.any?
      puts "\n🔍 DojoPaaS関連のNote:"
      dojopaas_notes.each do |note|
        puts "  - #{note['Name']} (ID: #{note['ID']})"
      end
    end
    
  else
    puts "❌ Noteリソースの取得に失敗しました"
  end
  
rescue => e
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end