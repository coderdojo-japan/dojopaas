#!/usr/bin/env ruby

# 初期化依頼Issueのパターンを正規表現で抽出するテスト
# すべての既存Issueで動作することを確認

require 'json'

# 実際のIssueサンプル
test_cases = [
  # テンプレート準拠
  {
    text: "CoderDojo【仙台若林】の【伊深】です。当該サーバー（IPアドレス：【153.125.128.236】）の初期化をお願いします。cc/ @yasulab",
    expected_dojo: "仙台若林",
    expected_ip: "153.125.128.236"
  },
  # 角カッコなし
  {
    text: "CoderDojo 青梅 の 鹿野市郎 です。当該サーバー（IPアドレス：【153.125.147.19】）の初期化をお願いします。cc/ @yasulab",
    expected_dojo: "青梅",
    expected_ip: "153.125.147.19"
  },
  # スペースなし
  {
    text: "CoderDojo HARUMIの松本博文です。当該サーバー（IPアドレス：【153.127.192.200】）の初期化をお願いします。",
    expected_dojo: "HARUMI",
    expected_ip: "153.127.192.200"
  },
  # 読点あり
  {
    text: "CoderDojo狛江の、おおやけハジメです。当該サーバー（IPアドレス：153.125.131.180）の初期化をお願いします。",
    expected_dojo: "狛江",
    expected_ip: "153.125.131.180"
  },
  # 英語道場名
  {
    text: "CoderDojo【coderdojo-naha】の【高江洲】です。当該サーバー（IPアドレス：【133.242.230.237】）の初期化をお願いします。",
    expected_dojo: "coderdojo-naha",
    expected_ip: "133.242.230.237"
  },
  # "の"のあとに名前がない
  {
    text: "CoderDojo HARUMI の松本です。当該サーバー（IPアドレス：【153.127.192.200】）の初期化をお願いします。",
    expected_dojo: "HARUMI",
    expected_ip: "153.127.192.200"
  }
]

# 改善された正規表現パターン
DOJO_PATTERNS = [
  # パターン1: CoderDojo【道場名】の形式
  /CoderDojo\s*【([^】]+)】/,
  # パターン2: CoderDojo 道場名 の形式（スペースあり）
  /CoderDojo\s+([^\s【]+)\s+の/,
  # パターン3: CoderDojo道場名の形式（スペースなし）
  /CoderDojo\s*([^\s【の]+)の/,
]

# IPアドレスパターン（角カッコあり・なし両対応）
IP_PATTERN = /(?:IPアドレス|IP)[：:]\s*【?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})】?/

def extract_dojo_name(text)
  DOJO_PATTERNS.each do |pattern|
    if match = text.match(pattern)
      return match[1].strip
    end
  end
  nil
end

def extract_ip_address(text)
  if match = text.match(IP_PATTERN)
    return match[1]
  end
  nil
end

# テスト実行
puts "=== 正規表現パターンテスト ==="
puts ""

success_count = 0
failure_count = 0

test_cases.each_with_index do |test_case, index|
  puts "テストケース #{index + 1}:"
  puts "  入力: #{test_case[:text][0..50]}..."
  
  extracted_dojo = extract_dojo_name(test_case[:text])
  extracted_ip = extract_ip_address(test_case[:text])
  
  dojo_ok = extracted_dojo == test_case[:expected_dojo]
  ip_ok = extracted_ip == test_case[:expected_ip]
  
  if dojo_ok && ip_ok
    puts "  ✅ 成功"
    success_count += 1
  else
    puts "  ❌ 失敗"
    failure_count += 1
  end
  
  puts "    道場名: '#{extracted_dojo}' (期待値: '#{test_case[:expected_dojo]}') #{dojo_ok ? '✓' : '✗'}"
  puts "    IP: '#{extracted_ip}' (期待値: '#{test_case[:expected_ip]}') #{ip_ok ? '✓' : '✗'}"
  puts ""
end

puts "=== 結果 ==="
puts "成功: #{success_count}/#{test_cases.length}"
puts "失敗: #{failure_count}/#{test_cases.length}"
puts "成功率: #{(success_count.to_f / test_cases.length * 100).round(1)}%"

# 実際のGitHub Issueでテスト（オプション）
if ARGV[0] == "--real"
  puts ""
  puts "=== 実際のIssueでテスト ==="
  
  # GitHub CLIで初期化依頼のIssueを取得
  issues_json = `gh issue list --repo coderdojo-japan/dojopaas --state all --limit 20 --search "初期化" --json number,body 2>/dev/null`
  
  if $?.success?
    issues = JSON.parse(issues_json)
    
    issues.each do |issue|
      next if issue['body'].nil? || issue['body'].empty?
      
      dojo = extract_dojo_name(issue['body'])
      ip = extract_ip_address(issue['body'])
      
      if dojo && ip
        puts "Issue ##{issue['number']}: ✅ 道場='#{dojo}', IP='#{ip}'"
      else
        puts "Issue ##{issue['number']}: ⚠️  道場='#{dojo}', IP='#{ip}'"
        puts "  本文: #{issue['body'][0..100]}..."
      end
    end
  else
    puts "GitHub CLIでIssueを取得できませんでした"
  end
end