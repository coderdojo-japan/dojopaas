#!/usr/bin/env ruby

# サーバーのセットアップ状態を確認するスクリプト
# 使い方: ruby verify_server_setup.rb <IPアドレス>

require 'dotenv/load'
require 'open3'
require 'json'
require_relative '../smart_wait_helper'

include SmartWaitHelper

if ARGV.empty?
  puts "使い方: ruby #{$0} <IPアドレス>"
  puts "例: ruby #{$0} 133.242.226.37"
  exit 1
end

ip_address = ARGV[0]
username = 'ubuntu'

puts "========================================"
puts "サーバーセットアップ確認スクリプト"
puts "対象サーバー: #{username}@#{ip_address}"
puts "========================================"
puts ""

# SSH接続テスト（スマートウェイト付き）
puts "1. SSH接続テスト..."

begin
  result = wait_for_resource("SSH connection", -> {
    stdout, stderr, status = Open3.capture3(
      "ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no",
      "-o", "BatchMode=yes", "#{username}@#{ip_address}", "echo 'OK'"
    )
    
    {
      state: status.success? ? "connected" : "waiting",
      ready: status.success? && stdout.strip == 'OK',
      error: nil,
      data: { stdout: stdout, stderr: stderr }
    }
  }, max_wait_time: 120, initial_interval: 2, max_interval: 10)
  
  puts "✅ SSH接続成功"
rescue => e
  puts "❌ SSH接続失敗: #{e.message}"
  puts "サーバーの起動が完了していない可能性があります。"
  exit 1
end

puts ""
puts "2. スタートアップスクリプトの実行結果を確認..."
puts ""

# 確認用コマンドを作成
check_commands = <<-'COMMANDS'
echo "ANSIBLE_CHECK_START"
which ansible 2>/dev/null || echo "NOT_FOUND"
echo "ANSIBLE_CHECK_END"

echo "SSH_CONFIG_START"
grep -E '^(PermitRootLogin|PasswordAuthentication)' /etc/ssh/sshd_config 2>/dev/null || echo "NOT_FOUND"
echo "SSH_CONFIG_END"

echo "IPTABLES_START"
sudo iptables -L INPUT -n 2>/dev/null | grep -E "(DROP|ACCEPT.*dpt:(22|80|443))" || echo "NOT_CONFIGURED"
echo "IPTABLES_END"

echo "CLOUDINIT_START"
cloud-init status 2>/dev/null || echo "NOT_FOUND"
echo "CLOUDINIT_END"

echo "HOSTNAME_START"
hostname
echo "HOSTNAME_END"
COMMANDS

# SSHで実行
stdout, stderr, status = Open3.capture3("ssh", "-o", "StrictHostKeyChecking=no", 
                                       "#{username}@#{ip_address}", check_commands)

if status.success?
  output = stdout
  
  # 結果を解析
  results = {
    ansible: output[/ANSIBLE_CHECK_START\n(.+?)\nANSIBLE_CHECK_END/m, 1],
    ssh_config: output[/SSH_CONFIG_START\n(.+?)\nSSH_CONFIG_END/m, 1],
    iptables: output[/IPTABLES_START\n(.+?)\nIPTABLES_END/m, 1],
    cloudinit: output[/CLOUDINIT_START\n(.+?)\nCLOUDINIT_END/m, 1],
    hostname: output[/HOSTNAME_START\n(.+?)\nHOSTNAME_END/m, 1]
  }
  
  # Ansible確認
  puts "🔍 Ansibleインストール確認"
  if results[:ansible] && results[:ansible] != "NOT_FOUND" && results[:ansible].include?("/")
    puts "✅ Ansible: インストール済み (#{results[:ansible].strip})"
    ansible_installed = true
  else
    puts "❌ Ansible: 未インストール"
    ansible_installed = false
  end
  puts ""
  
  # SSH設定確認
  puts "🔍 SSH設定確認"
  if results[:ssh_config] && results[:ssh_config] != "NOT_FOUND"
    puts "現在の設定:"
    puts results[:ssh_config]
    
    if results[:ssh_config].include?("PermitRootLogin no") && 
       results[:ssh_config].include?("PasswordAuthentication no")
      puts "✅ SSH設定: 正しく強化されています"
      ssh_secure = true
    else
      puts "❌ SSH設定: デフォルトのまま、または部分的にのみ適用"
      ssh_secure = false
    end
  else
    puts "❌ SSH設定ファイルが読み取れません"
    ssh_secure = false
  end
  puts ""
  
  # iptables確認
  puts "🔍 iptables設定確認"
  if results[:iptables] && results[:iptables] != "NOT_CONFIGURED"
    puts "検出されたルール:"
    puts results[:iptables]
    
    iptables_configured = results[:iptables].include?("DROP") || 
                         results[:iptables].include?("dpt:22") ||
                         results[:iptables].include?("dpt:80") ||
                         results[:iptables].include?("dpt:443")
    
    if iptables_configured
      puts "✅ iptables: 設定されています"
      puts "  検出されたポート:"
      puts "  - ポート22 (SSH): #{results[:iptables].include?('dpt:22') ? '✅' : '❌'}"
      puts "  - ポート80 (HTTP): #{results[:iptables].include?('dpt:80') ? '✅' : '❌'}"
      puts "  - ポート443 (HTTPS): #{results[:iptables].include?('dpt:443') ? '✅' : '❌'}"
    else
      puts "❌ iptables: デフォルト設定のまま"
    end
  else
    puts "❌ iptables: 未設定"
    iptables_configured = false
  end
  puts ""
  
  # cloud-initステータス
  puts "🔍 cloud-initステータス"
  if results[:cloudinit] && results[:cloudinit] != "NOT_FOUND"
    puts results[:cloudinit].strip
  else
    puts "cloud-initが見つかりません"
  end
  puts ""
  
  # システム情報
  puts "🔍 システム情報"
  puts "ホスト名: #{results[:hostname]&.strip || 'N/A'}"
  puts ""
  
  # 総合判定
  puts "========================================"
  puts "📊 総合判定"
  puts "========================================"
  
  if ansible_installed && ssh_secure && iptables_configured
    puts "✅ スタートアップスクリプトは正常に実行されました！"
    puts "  すべての設定が正しく適用されています。"
  else
    puts "⚠️  スタートアップスクリプトの一部が実行されていない可能性があります"
    puts ""
    puts "未適用の項目:"
    puts "  - Ansible: #{ansible_installed ? 'OK ✅' : '未インストール ❌'}"
    puts "  - SSH設定: #{ssh_secure ? 'OK ✅' : '未設定 ❌'}"
    puts "  - iptables: #{iptables_configured ? 'OK ✅' : '未設定 ❌'}"
    puts ""
    puts "トラブルシューティング:"
    puts "1. cloud-initのログを確認:"
    puts "   ssh #{username}@#{ip_address} 'sudo tail -100 /var/log/cloud-init-output.log'"
    puts ""
    puts "2. cloud-initのエラーログ:"
    puts "   ssh #{username}@#{ip_address} 'sudo grep -i error /var/log/cloud-init.log'"
  end
  
else
  puts "❌ エラーが発生しました: #{stderr}"
  exit 1
end

puts ""
puts "========================================"
puts "確認完了"
puts "========================================"