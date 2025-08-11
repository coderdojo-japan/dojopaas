require "rspec/core/rake_task"
require 'ipaddr'

RSpec::Core::RakeTask.new(:spec)

task :test => :spec

# ================================================================
# DojoPaaS 管理タスク
# ================================================================
# このRakefileは実行可能な操作のカタログとして機能します
# 'rake -T' ですべての利用可能なタスクを確認できます
# ================================================================

desc "利用可能なDojoPaaS管理タスクをすべて表示"
task :default do
  puts "\n🔧 DojoPaaS 管理タスク"
  puts "=" * 50
  puts "'rake -T' ですべての利用可能なタスクを確認"
  puts "'rake -D [タスク名]' で詳細な説明を表示"
  puts "=" * 50
  sh "rake -T"
end

namespace :server do
  desc "初期化依頼用のサーバー情報を検索 (GitHub Actions用)"
  task :find_for_initialization, [:ip] => :validate_env do |t, args|
    ip = args[:ip] || ENV['IP_ADDRESS']
    
    unless ip
      abort "❌ エラー: IPアドレスが必要です\n" \
            "使い方: rake server:find_for_initialization[192.168.1.1]\n" \
            "または: IP_ADDRESS=192.168.1.1 rake server:find_for_initialization"
    end
    
    # セキュリティのためRubyのIPAddrを使用してIPアドレスを検証
    begin
      validated_ip = IPAddr.new(ip)
      
      # プライベート/特殊IPをチェック
      if validated_ip.private? || validated_ip.loopback? || validated_ip.link_local?
        abort "❌ エラー: プライベートまたは特殊IPアドレスは許可されていません: #{ip}"
      end
      
      # さくらクラウドのIP範囲の追加検証（オプション）
      if ENV['VALIDATE_SAKURA_RANGE'] == 'true'
        unless in_sakura_cloud_range?(validated_ip)
          abort "❌ エラー: IPアドレスがさくらクラウドの範囲外です: #{ip}"
        end
      end
      
      validated_ip_str = validated_ip.to_s
    rescue IPAddr::InvalidAddressError => e
      abort "❌ エラー: 無効なIPアドレス形式: #{ip}\n#{e.message}"
    end
    
    puts "✅ 有効なIPアドレス: #{validated_ip_str}"
    puts "🔍 サーバー情報を検索中..."
    puts "-" * 50
    
    # 検証済みIPでinitialize_server.rbスクリプトを実行
    sh "ruby scripts/initialize_server.rb --find #{validated_ip_str}"
  end
  
  desc "Issue URLでサーバーを検索（開発補助）"
  task :find_by_issue, [:issue_url] => :validate_env do |t, args|
    issue_url = args[:issue_url] || ENV['ISSUE_URL']
    
    unless issue_url
      abort "❌ エラー: Issue URLが必要です\n" \
            "使い方: rake server:find_by_issue[https://github.com/.../issues/XXX]"
    end
    
    # Issue URLフォーマットを検証
    unless issue_url =~ %r{^https://github\.com/coderdojo-japan/dojopaas/issues/\d+$}
      abort "❌ エラー: 無効なIssue URLフォーマット: #{issue_url}\n" \
            "期待される形式: https://github.com/coderdojo-japan/dojopaas/issues/XXX"
    end
    
    puts "📋 Issue処理中: #{issue_url}"
    puts "🔍 サーバー情報を抽出中..."
    puts "-" * 50
    
    sh "ruby scripts/initialize_server.rb --find #{issue_url}"
  end
  
  # 検証ヘルパータスク
  task :validate_env do
    if ENV['CI'] == 'true'
      # CI環境では必要なシークレットをチェック
      required_vars = %w[SACLOUD_ACCESS_TOKEN SACLOUD_ACCESS_TOKEN_SECRET]
      missing_vars = required_vars.reject { |var| ENV[var] }
      
      unless missing_vars.empty?
        abort "❌ エラー: CI環境で必要な環境変数が不足: #{missing_vars.join(', ')}\n" \
              "GitHub Secretsとして設定してください"
      end
    end
  end
end

# ヘルパーメソッド（将来のフェーズで拡張予定）
def in_sakura_cloud_range?(ip_addr)
  # さくらクラウドのIP範囲（現時点では簡略化）
  sakura_ranges = [
    IPAddr.new("153.127.0.0/16"),  # 石狩第二ゾーン
    IPAddr.new("163.43.0.0/16"),   # 東京ゾーン
    IPAddr.new("133.242.0.0/16"),  # 大阪ゾーン
  ]
  
  sakura_ranges.any? { |range| range.include?(ip_addr) }
end

# ================================================================
# 将来のタスク（後続のPRで実装予定）
# ================================================================
# 
# フェーズ2: よく使うコマンド
# - rake server:initialize[ip]     # サーバーを削除して再作成
# - rake server:status[name]       # サーバーステータス確認
# - rake deploy:production         # servers.csvからデプロイ
# - rake test:verify[ip]          # サーバーセットアップを検証
# 
# フェーズ3: 完全統合
# - rake maintenance:cleanup       # 孤立したリソースをクリーンアップ
# - rake maintenance:audit         # 監査レポート生成
# - rake docs:generate            # ドキュメント自動生成
# 
# 詳細なロードマップは docs/plan_rakefile_migration.md を参照
# ================================================================
