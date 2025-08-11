require "rspec/core/rake_task"
require 'ipaddr'
require 'fileutils'
require 'json'
require 'time'

RSpec::Core::RakeTask.new(:spec)

task :test => :spec

# Rakeの高度な機能を活用した改善
# - 依存関係の明確化
# - インクリメンタル実行
# - エラーハンドリング
# - 並列実行サポート

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
  # ========================================
  # 環境検証タスク（他のタスクの前提条件）
  # ========================================
  task :check_api_credentials do
    required_vars = %w[SACLOUD_ACCESS_TOKEN SACLOUD_ACCESS_TOKEN_SECRET]
    missing_vars = required_vars.reject { |var| ENV[var] }
    
    unless missing_vars.empty?
      abort "❌ エラー: 必要な環境変数が設定されていません: #{missing_vars.join(', ')}\n" \
            "設定方法:\n" \
            "  export SACLOUD_ACCESS_TOKEN=xxxx\n" \
            "  export SACLOUD_ACCESS_TOKEN_SECRET=xxxx"
    end
    
    puts "✅ API認証情報を確認しました" if ENV['VERBOSE']
  end
  
  # ========================================
  # ステータスファイル管理（インクリメンタル実行用）
  # ========================================
  directory 'tmp/rake_status'
  
  def status_file_for(task_name)
    "tmp/rake_status/#{task_name.gsub(':', '_')}.json"
  end
  
  def save_task_status(task_name, status)
    FileUtils.mkdir_p('tmp/rake_status')
    File.write(status_file_for(task_name), JSON.pretty_generate({
      task: task_name,
      status: status,
      timestamp: Time.now.iso8601,
      details: status[:details] || {}
    }))
  end
  
  def load_task_status(task_name)
    file = status_file_for(task_name)
    return nil unless File.exist?(file)
    JSON.parse(File.read(file))
  rescue JSON::ParserError
    nil
  end
  
  
  # ========================================
  # サーバー情報検索タスク（統一命名パターン）
  # ========================================
  desc "IPアドレスでサーバーを検索"
  task :find_by_ip, [:ip] => [:check_api_credentials, :validate_env] do |t, args|
    ip = args[:ip] || ENV['IP_ADDRESS']
    
    unless ip
      abort "❌ エラー: IPアドレスが必要です\n" \
            "使い方: rake server:find_by_ip[192.168.1.1]\n" \
            "または: IP_ADDRESS=192.168.1.1 rake server:find_by_ip"
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
  
  # ========================================
  # その他の検索タスク（統一命名パターン）
  # ========================================
  desc "Issue URLでサーバーを検索"
  task :find_by_issue, [:issue_url] => [:check_api_credentials, :validate_env] do |t, args|
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
  
  # ========================================
  # サーバー削除タスク（段階的実行）
  # ========================================
  desc "サーバー名でサーバーを検索"
  task :find_by_name, [:name] => [:check_api_credentials, :validate_env] do |t, args|
    name = args[:name] || ENV['SERVER_NAME']
    
    unless name
      abort "❌ エラー: サーバー名が必要です\n" \
            "使い方: rake server:find_by_name[coderdojo-tokyo]"
    end
    
    puts "🔍 サーバー名で検索: #{name}"
    puts "-" * 50
    
    sh "ruby scripts/initialize_server.rb --find #{name}"
  end
  
  # ========================================
  # サーバー削除タスク（段階的実行）
  # ========================================
  desc "サーバー削除の準備（情報確認のみ）"
  task :prepare_deletion, [:ip] => [:check_api_credentials, :validate_env] do |t, args|
    ip = args[:ip] || ENV['IP_ADDRESS']
    
    unless ip
      abort "❌ エラー: IPアドレスが必要です"
    end
    
    puts "🔍 削除対象サーバーの情報を確認中..."
    
    # 削除準備状態を保存（インクリメンタル実行用）
    # find_by_ipと同じロジックを使用しても、別途実行する
    result = `ruby scripts/initialize_server.rb --find #{ip} 2>&1`
    if $?.success?
      save_task_status('prepare_deletion', {
        success: true,
        ip: ip,
        output: result
      })
      puts result
      puts "\n✅ 削除準備が完了しました"
      puts "次のステップ: rake server:execute_deletion[#{ip}]"
    else
      abort "❌ サーバー情報の取得に失敗しました\n#{result}"
    end
  end
  
  desc "サーバーを削除（危険・要確認）"
  task :execute_deletion, [:ip, :force] => :prepare_deletion do |t, args|
    ip = args[:ip] || ENV['IP_ADDRESS']
    force = args[:force] || ENV['FORCE']
    
    # 前のタスクの結果を確認
    prep_status = load_task_status('prepare_deletion')
    if prep_status.nil? || prep_status['ip'] != ip
      abort "❌ エラー: 先に prepare_deletion を実行してください"
    end
    
    # 削除実行
    cmd = "ruby scripts/initialize_server.rb --delete #{ip}"
    cmd += " --force" if force
    
    puts "⚠️  サーバー削除を実行します: #{ip}"
    sh cmd do |ok, res|
      if ok
        save_task_status('execute_deletion', {
          success: true,
          ip: ip,
          deleted_at: Time.now.iso8601
        })
        puts "✅ サーバー削除が完了しました"
      else
        abort "❌ サーバー削除に失敗しました"
      end
    end
  end
  
  desc "削除後の空コミット作成"
  task :create_empty_commit, [:issue_number] => :execute_deletion do |t, args|
    issue_number = args[:issue_number] || ENV['ISSUE_NUMBER']
    
    unless issue_number
      abort "❌ エラー: Issue番号が必要です"
    end
    
    # 削除状態を確認
    del_status = load_task_status('execute_deletion')
    if del_status.nil? || !del_status['success']
      abort "❌ エラー: サーバー削除が完了していません"
    end
    
    message = "Fix ##{issue_number}: Initialize server (deleted at #{del_status['deleted_at']})"
    sh "git commit --allow-empty -m '#{message}'" do |ok, res|
      if ok
        puts "✅ 空コミットを作成しました"
        puts "次のステップ: git push でCI/CDを実行"
      else
        abort "❌ コミット作成に失敗しました"
      end
    end
  end
  
  # ========================================
  # 完全な初期化フロー（依存関係チェーン）
  # ========================================
  desc "サーバー初期化の完全なフロー（Issue番号必須）"
  task :initialize, [:ip, :issue_number] do |t, args|
    ip = args[:ip] || ENV['IP_ADDRESS']
    issue_number = args[:issue_number] || ENV['ISSUE_NUMBER']
    
    unless ip && issue_number
      abort "❌ エラー: IPアドレスとIssue番号が必要です\n" \
            "使用方法: rake server:initialize[192.168.1.1,123]"
    end
    
    puts "🚀 サーバー初期化フローを開始します"
    puts "  IPアドレス: #{ip}"
    puts "  Issue: ##{issue_number}"
    puts "=" * 50
    
    # 依存タスクを順次実行
    Rake::Task['server:prepare_deletion'].invoke(ip)
    
    puts "\n⚠️  削除を実行しますか？ (yes/no)"
    response = STDIN.gets.chomp
    
    if response.downcase == 'yes'
      Rake::Task['server:execute_deletion'].invoke(ip, 'true')
      Rake::Task['server:create_empty_commit'].invoke(issue_number)
      
      puts "\n" + "=" * 50
      puts "✅ サーバー初期化フローが完了しました"
      puts "最後のステップ: git push でCI/CDを実行してください"
    else
      puts "❌ 処理を中止しました"
    end
  end
  
  # 検証ヘルパータスク（改善版）
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
# 並列実行タスク（Rakeの高度な機能）
# ================================================================
namespace :parallel do
  desc "複数サーバーの状態を並列チェック"
  multitask :check_all => ['server:validate_env'] do
    # servers.csvから全サーバーをチェック
    require 'csv'
    servers = CSV.read('servers.csv', headers: true)
    
    # 並列でステータスチェックを実行
    threads = servers.map do |server|
      Thread.new do
        begin
          result = `ruby scripts/initialize_server.rb --find #{server['Name']} 2>&1`
          { name: server['Name'], status: $?.success? ? 'OK' : 'ERROR', details: result }
        rescue => e
          { name: server['Name'], status: 'ERROR', details: e.message }
        end
      end
    end
    
    results = threads.map(&:value)
    
    # 結果をサマリー表示
    puts "\n" + "=" * 50
    puts "サーバーステータスサマリー"
    puts "=" * 50
    results.each do |r|
      status_icon = r[:status] == 'OK' ? '✅' : '❌'
      puts "#{status_icon} #{r[:name]}: #{r[:status]}"
    end
  end
end

# ================================================================
# クリーンタスク（Rake標準機能の活用）
# ================================================================
require 'rake/clean'

CLEAN.include('tmp/rake_status/*.json')
CLOBBER.include('tmp/rake_status')

desc "Rakeタスクのステータスファイルをクリア"
task :clear_status do
  rm_rf 'tmp/rake_status'
  puts "✅ ステータスファイルをクリアしました"
end

# ================================================================
# 将来のタスク（フェーズ2以降）
# ================================================================
# 
# フェーズ2: 高度な自動化
# - rake server:batch_initialize    # 複数サーバーの一括初期化
# - rake server:health_check        # ヘルスチェック実行
# - rake deploy:canary             # カナリアデプロイ
# 
# フェーズ3: 完全統合
# - rake maintenance:scheduled      # スケジュールメンテナンス
# - rake report:weekly             # 週次レポート生成
# - rake backup:all                # 全サーバーバックアップ
# 
# 詳細なロードマップは docs/plan_rakefile_migration.md を参照
# ================================================================
