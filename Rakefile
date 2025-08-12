require 'rake/testtask'
require 'fileutils'
require 'json'
require 'time'
require 'net/http'
require 'uri'
require 'csv'

# Minitestタスクの定義
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false  # 詳細な実行コマンドを非表示
  t.warning = false  # 警告を無効化（必要に応じて）
end

# 短縮エイリアス
task :t => :test

# テストの詳細情報を表示
desc "Run all tests with detailed output"
task :test_verbose do
  ENV['TESTOPTS'] = '--verbose'
  Rake::Task[:test].invoke
end

# CSV検証のみ実行
desc "Validate CSV format only"
task :test_csv do
  ruby "test/csv_test.rb"
end

task :default => :test

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
    
    # IPアドレスの検証（SakuraServerUserAgentの共通メソッドを使用）
    require_relative 'scripts/sakura_server_user_agent'
    
    unless SakuraServerUserAgent.valid_ip_address?(ip)
      abort "❌ エラー: 無効なIPアドレス形式: #{ip}"
    end
    
    # IPアドレスを正規化
    validated_ip_str = SakuraServerUserAgent.normalize_ip_address(ip)
    
    puts "✅ 有効なIPアドレス: #{validated_ip_str}"
    puts "🔍 サーバー情報を検索中..."
    puts "-" * 50
    
    # 検証済みIPでinitialize_server.rbスクリプトを実行（コマンドエコーを抑制）
    sh "ruby scripts/initialize_server.rb --find #{validated_ip_str}", verbose: false
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
    
    sh "ruby scripts/initialize_server.rb --find #{issue_url}", verbose: false
  end
  
  # ========================================
  # サーバー削除タスク（段階的実行）
  # ========================================
  desc "サーバー名でサーバーを検索"
  task :find_by_name, [:name] => [:check_api_credentials, :validate_env] do |t, args|
    name = args[:name] || ENV['SERVER_NAME']
    
    unless name
      abort "❌ エラー: サーバー名が必要です\n" \
            "使い方: rake server:find_by_name[coderdojo-japan]"
    end
    
    puts "🔍 サーバー名で検索: #{name}"
    puts "-" * 50
    
    sh "ruby scripts/initialize_server.rb --find #{name}", verbose: false
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
    # forceフラグを明示的にブール値として扱う
    force = args[:force].to_s.downcase == 'true' || ENV['FORCE'].to_s.downcase == 'true'
    
    # 前のタスクの結果を確認
    prep_status = load_task_status('prepare_deletion')
    if prep_status.nil? || prep_status['status'].nil? || prep_status['status']['ip'] != ip
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
  task :create_empty_commit, [:issue_number] do |t, args|
    issue_number = args[:issue_number] || ENV['ISSUE_NUMBER']
    
    unless issue_number
      abort "❌ エラー: Issue番号が必要です"
    end
    
    # 削除状態を確認
    del_status = load_task_status('execute_deletion')
    if del_status.nil? || !del_status['status'] || !del_status['status']['success']
      abort "❌ エラー: サーバー削除が完了していません"
    end
    
    deleted_at = del_status['status']['deleted_at'] || Time.now.iso8601
    message = "Fix ##{issue_number}: Initialize server (deleted at #{deleted_at})"
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
  
  # ========================================
  # サーバー一覧参照タスク
  # ========================================
  desc "現在稼働中のサーバー一覧を表示"
  task :list do
    require_relative 'scripts/sakura_server_user_agent'
    
    puts "📋 サーバー一覧を取得中..."
    puts "データソース: #{SakuraServerUserAgent::INSTANCES_CSV_URL}"
    puts "-" * 50
    
    begin
      uri = URI(SakuraServerUserAgent::INSTANCES_CSV_URL)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        # エンコーディングを明示的に設定してCSVを解析（無効な文字を安全に処理）
        response.body.force_encoding('UTF-8').scrub('?')
        csv_data = CSV.parse(response.body, headers: true)
        
        puts "📊 サーバー一覧（#{csv_data.length}台）:"
        puts ""
        
        csv_data.each do |row|
          puts "  🖥️  #{row['Name']}"
          puts "      IPアドレス: #{row['IP Address']}"  # スペースを追加
          puts "      説明: #{row['Description']}" if row['Description']
          puts ""
        end
        
        # テスト用サーバーのチェック
        require_relative 'scripts/initialize_server'
        test_servers = csv_data.select do |row|
          ServerInitializer.safe_test_server?(row['Name'])
        end
        
        puts "🧪 テスト用サーバー（#{test_servers.length}台）:"
        if test_servers.any?
          test_servers.each do |server|
            puts "  ✅ #{server['Name']} - #{server['IP Address']}"  # スペースを追加
          end
        else
          puts "  （テスト用サーバーがありません）"
        end
        puts ""
        
      else
        abort "❌ エラー: サーバー一覧の取得に失敗しました (HTTP #{response.code})"
      end
      
    rescue => e
      abort "❌ エラー: #{e.message}"
    end
  end
end

# ヘルパーメソッド（将来の拡張用に保持）
# 注: 現在は使用されていません（YAGNI原則により簡素化）
# def in_sakura_cloud_range?(ip_addr)
#   sakura_ranges = [
#     IPAddr.new("153.127.0.0/16"),  # 石狩第二ゾーン
#     IPAddr.new("163.43.0.0/16"),   # 東京ゾーン
#     IPAddr.new("133.242.0.0/16"),  # 大阪ゾーン
#   ]
#   sakura_ranges.any? { |range| range.include?(ip_addr) }
# end

# ================================================================
# 並列実行タスク（将来の実装用にコメントアウト）
# ================================================================
# YAGNI原則により、実際に必要になるまでコメントアウト
# 注意: 200サーバーの並列チェックはAPI制限のリスクあり
#
# namespace :parallel do
#   desc "複数サーバーの状態を並列チェック"
#   multitask :check_all => ['server:validate_env'] do
#     # servers.csvから全サーバーをチェック
#     servers = CSV.read('servers.csv', headers: true)
#     
#     # 並列でステータスチェックを実行
#     threads = servers.map do |server|
#       Thread.new do
#         begin
#           result = `ruby scripts/initialize_server.rb --find #{server['Name']} 2>&1`
#           { name: server['Name'], status: $?.success? ? 'OK' : 'ERROR', details: result }
#         rescue => e
#           { name: server['Name'], status: 'ERROR', details: e.message }
#         end
#       end
#     end
#     
#     results = threads.map(&:value)
#     
#     # 結果をサマリー表示
#     puts "\n" + "=" * 50
#     puts "サーバーステータスサマリー"
#     puts "=" * 50
#     results.each do |r|
#       status_icon = r[:status] == 'OK' ? '✅' : '❌'
#       puts "#{status_icon} #{r[:name]}: #{r[:status]}"
#     end
#   end
# end

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
