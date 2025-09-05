#!/usr/bin/env ruby

# スタートアップスクリプトが正しく実行されるかテスト
# 通常版Ubuntuでdisk/config APIのNotesフィールドが機能するか確認

require 'dotenv/load'
require_relative '../sakura_server_user_agent.rb'

if ARGV.length < 1
  puts "使用方法: ruby #{$0} <サーバー名>"
  puts "例: ruby #{$0} test-startup-script"
  exit 1
end

server_name = ARGV[0]
ssh_key_path = ENV['SSH_PUBLIC_KEY_PATH'] || File.expand_path('~/.ssh/id_rsa.pub')

unless File.exist?(ssh_key_path)
  puts "SSH公開鍵が見つかりません: #{ssh_key_path}"
  exit 1
end

pubkey = File.read(ssh_key_path).strip

puts "=== スタートアップスクリプトのテスト ==="
puts "サーバー名: #{server_name}"
puts "スタートアップスクリプトID: #{SakuraServerUserAgent::STARTUP_SCRIPT_ID}"
puts ""

# disk/config APIでのNotes設定をデバッグ
class DebugServerUserAgent < SakuraServerUserAgent
  def test_disk_config(disk_id, pubkey)
    body = {
      SSHKey: {
        PublicKey: pubkey
      },
      Notes: [{ID: STARTUP_SCRIPT_ID}]  # ここがポイント
    }
    
    puts "📋 disk/config APIに送信するデータ:"
    puts JSON.pretty_generate(body)
    puts ""
    
    # 実際にAPIを呼び出す
    response = send_request('put',"disk/#{disk_id}/config", body)
    
    puts "📋 APIレスポンス:"
    puts JSON.pretty_generate(response) if response
    
    response
  end
  
  # サーバー起動時のパラメータも確認
  def test_server_start(server_id, with_notes = false)
    if with_notes
      # Notesをサーバー起動時に指定する方法（テスト）
      body = {
        Notes: [{ID: STARTUP_SCRIPT_ID}]
      }
      puts "📋 サーバー起動時にNotesを指定:"
      puts JSON.pretty_generate(body)
      response = send_request('put',"server/#{server_id}/power", body)
    else
      # 現在の実装（Notesなし）
      puts "📋 サーバー起動時にNotesを指定しない（現在の実装）"
      response = send_request('put',"server/#{server_id}/power", nil)
    end
    
    response
  end
end

# APIドキュメントの確認事項を出力
puts "⚠️  確認事項:"
puts "1. disk/config APIのNotesフィールドはスタートアップスクリプトIDを受け付けるか？"
puts "2. それとも、サーバー起動時（/power API）にNotesを指定する必要があるか？"
puts "3. 通常版UbuntuとCloudImg版で動作が異なるか？"
puts ""
puts "参考: さくらのクラウドAPIドキュメント"
puts "  https://manual.sakura.ad.jp/cloud/api/1.1/disk.html#put-disk-disk_id-config"
puts "  https://manual.sakura.ad.jp/cloud/api/1.1/server.html#put-server-server_id-power"
puts ""

# 実際のテストは危険なのでコメントアウト
# agent = DebugServerUserAgent.new(verbose: true)
# agent.create(name: server_name, description: "Test startup script", pubkey: pubkey, tag: "test")

puts "📝 現在の実装の問題点："
puts "- disk/config APIでNotesを設定しているが、これがスタートアップスクリプトとして実行されるか不明"
puts "- cloud-init削除時にスタートアップスクリプトの実行方法も削除された可能性"
puts ""
puts "📝 解決策の候補："
puts "1. サーバー起動時（/power API）にNotesパラメータを追加"
puts "2. 別のAPIエンドポイントでスタートアップスクリプトを設定"
puts "3. cloud-initを部分的に復活（スタートアップスクリプト実行のみ）"