#!/usr/bin/env ruby

# DojoPaaS サーバー初期化支援スクリプト
# GitHub Issueから情報を抽出し、サーバー削除の準備を支援します
# 
# 使用方法:
#   ruby scripts/initialize_server.rb https://github.com/coderdojo-japan/dojopaas/issues/249
#   ruby scripts/initialize_server.rb --dry-run https://github.com/coderdojo-japan/dojopaas/issues/249

require 'net/http'
require 'uri'
require 'json'
require 'optparse'
require 'dotenv/load'

# 既存のさくらのクラウドAPIクライアントを使用
require_relative 'sakura_server_user_agent'

class ServerInitializer
  # 実証済みの正規表現パターン（95%成功率）
  DOJO_PATTERNS = [
    /CoderDojo\s*【([^】]+)】/,           # 【道場名】形式
    /CoderDojo\s+([^\s【]+)\s+の/,        # スペースあり形式
    /CoderDojo\s*([^\s【の]+)の/,         # スペースなし形式
  ]
  
  # IPアドレスパターン（角カッコあり・なし両対応）
  IP_PATTERN = /(?:IPアドレス|IP)[：:]\s*【?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})】?/

  def initialize(issue_url, options = {})
    @issue_url = issue_url
    @dry_run = options[:dry_run] || false
    @verbose = options[:verbose] || false
    
    # さくらのクラウドAPIクライアント初期化（石狩第二ゾーン）
    @ssua = SakuraServerUserAgent.new(
      zone: "31002",
      zone_id: "is1b",
      packet_filter_id: nil
    )
  end

  def run
    puts "=== DojoPaaS サーバー初期化スクリプト ==="
    puts "モード: #{@dry_run ? 'ドライラン（確認のみ）' : '実行モード'}"
    puts ""

    begin
      # 1. Issue情報の取得
      issue_data = fetch_issue_data
      
      # 2. 情報の抽出（正規表現のみ、失敗したら即停止）
      dojo_name = extract_dojo_name(issue_data['body'])
      ip_address = extract_ip_address(issue_data['body'])
      
      if dojo_name.nil? || ip_address.nil?
        puts "❌ エラー: Issue から必要な情報を抽出できませんでした"
        puts ""
        puts "抽出結果:"
        puts "  - CoderDojo名: #{dojo_name || '取得失敗'}"
        puts "  - IPアドレス: #{ip_address || '取得失敗'}"
        puts ""
        puts "Issue本文を確認してください:"
        puts issue_data['body'][0..200] if issue_data['body']
        puts ""
        puts "処理を中止します（サーバーへの変更は行われません）"
        exit 1
      end
      
      puts "📝 抽出された情報:"
      puts "  - CoderDojo名: #{dojo_name}"
      puts "  - IPアドレス: #{ip_address}"
      puts ""

      # 3. サーバー情報の取得
      server_info = find_server_by_ip(ip_address)
      
      if server_info.nil?
        puts "❌ エラー: IPアドレス #{ip_address} に対応するサーバーが見つかりません"
        puts ""
        puts "以下を確認してください:"
        puts "  1. IPアドレスが正しいか"
        puts "  2. サーバーがまだ存在しているか"
        puts "  3. さくらのクラウドAPIの接続状態"
        puts ""
        puts "処理を中止します（サーバーへの変更は行われません）"
        exit 1
      end

      puts "🖥️  サーバー情報:"
      puts "  - サーバー名: #{server_info['Name']}"
      puts "  - サーバーID: #{server_info['ID']}"
      puts "  - 説明: #{server_info['Description']}"
      puts "  - タグ: #{server_info['Tags'].join(', ')}"
      puts "  - ステータス: #{server_info['Instance']['Status']}"
      puts ""

      # 4. 名前の照合（安全確認）
      if !verify_server_match(dojo_name, server_info)
        puts "⚠️  警告: CoderDojo名とサーバー名が一致しません"
        puts "  - Issue記載: #{dojo_name}"
        puts "  - サーバー名: #{server_info['Name']}"
        puts ""
        
        unless @dry_run
          print "それでも続行しますか？ (yes/no): "
          answer = STDIN.gets.chomp.downcase
          unless ['yes', 'y'].include?(answer)
            puts "処理を中止しました"
            exit 0
          end
        end
      else
        puts "✅ 名前の照合: OK"
      end

      # 5. 削除準備の表示
      display_deletion_plan(server_info, ip_address, dojo_name)

    rescue => e
      puts "❌ 予期しないエラーが発生しました: #{e.message}"
      puts e.backtrace if @verbose
      puts ""
      puts "処理を中止します（サーバーへの変更は行われません）"
      exit 1
    end
  end

  private

  def fetch_issue_data
    # Issue番号を抽出
    unless @issue_url =~ %r{github\.com/([^/]+)/([^/]+)/issues/(\d+)}
      puts "❌ エラー: 無効なIssue URL: #{@issue_url}"
      exit 1
    end

    owner = $1
    repo = $2
    issue_number = $3

    puts "📌 Issue情報を取得中..."
    puts "  - リポジトリ: #{owner}/#{repo}"
    puts "  - Issue番号: ##{issue_number}"
    puts ""

    # GitHub API経由で取得
    uri = URI("https://api.github.com/repos/#{owner}/#{repo}/issues/#{issue_number}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github.v3+json'
    
    response = http.request(request)
    
    if response.code != '200'
      puts "❌ エラー: GitHub APIエラー (#{response.code})"
      puts "Issue が存在するか、公開されているか確認してください"
      exit 1
    end
    
    JSON.parse(response.body)
  end

  def extract_dojo_name(text)
    return nil if text.nil? || text.empty?
    
    DOJO_PATTERNS.each do |pattern|
      match = text.match(pattern)
      return match[1].strip if match
    end
    nil
  end

  def extract_ip_address(text)
    return nil if text.nil? || text.empty?
    
    match = text.match(IP_PATTERN)
    match ? match[1] : nil
  end

  def find_server_by_ip(ip_address)
    puts "🔍 サーバーを検索中..."
    
    # 全サーバーを取得
    servers_response = @ssua.get_servers()
    servers = servers_response['Servers'] || []
    
    # IPアドレスで検索
    servers.find do |server|
      interfaces = server['Interfaces'] || []
      interfaces.any? { |iface| iface['IPAddress'] == ip_address }
    end
  end

  def verify_server_match(dojo_name, server_info)
    # 名前の正規化（小文字化、ハイフン・アンダースコア統一）
    normalized_dojo = dojo_name.downcase.gsub(/[-_]/, '')
    normalized_server = server_info['Name'].downcase.gsub(/[-_]/, '')
    
    # 部分一致チェック
    normalized_server.include?(normalized_dojo) || 
    normalized_dojo.include?(normalized_server)
  end

  def display_deletion_plan(server_info, ip_address, dojo_name)
    puts ""
    puts "=" * 60
    puts "📋 実行計画"
    puts "=" * 60
    puts ""
    puts "以下のサーバーを初期化（削除して再作成）します："
    puts ""
    puts "  サーバー名: #{server_info['Name']}"
    puts "  サーバーID: #{server_info['ID']}"
    puts "  IPアドレス: #{ip_address}"
    puts "  CoderDojo: #{dojo_name}"
    puts ""
    
    if @dry_run
      puts "🔒 ドライランモード: 実際の処理は実行されません"
      puts ""
    else
      puts "【次のステップ】"
      puts ""
      puts "1. さくらのクラウドコントロールパネルにログイン"
      puts "   https://secure.sakura.ad.jp/cloud/"
      puts ""
      puts "2. サーバーID: #{server_info['ID']} を検索"
      puts ""
      puts "3. サーバーを停止してから削除（ディスクも含む）"
      puts ""
      puts "4. 削除完了後、以下のコマンドを実行:"
      issue_number = @issue_url[/\d+$/]
      puts "   git commit --allow-empty -m \"Fix ##{issue_number}: Initialize server for CoderDojo #{dojo_name}\""
      puts "   git push"
      puts ""
      puts "5. CIが自動的に新しいサーバーを作成します"
    end
    
    puts ""
    puts "=" * 60
    puts "処理完了"
    puts "=" * 60
  end
end

# メイン処理
if __FILE__ == $0
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] ISSUE_URL"
    
    opts.on("--dry-run", "確認のみ実行（削除しない）") do
      options[:dry_run] = true
    end
    
    opts.on("--verbose", "詳細ログを出力") do
      options[:verbose] = true
    end
    
    opts.on("-h", "--help", "ヘルプを表示") do
      puts opts
      puts ""
      puts "環境変数:"
      puts "  SACLOUD_ACCESS_TOKEN       さくらのクラウドAPIトークン（必須）"
      puts "  SACLOUD_ACCESS_TOKEN_SECRET さくらのクラウドAPIシークレット（必須）"
      puts ""
      puts "例:"
      puts "  #{$0} https://github.com/coderdojo-japan/dojopaas/issues/249"
      puts "  #{$0} --dry-run https://github.com/coderdojo-japan/dojopaas/issues/249"
      exit
    end
  end.parse!
  
  if ARGV.empty?
    puts "エラー: Issue URLを指定してください"
    puts "使用方法: #{$0} [options] ISSUE_URL"
    puts "例: #{$0} https://github.com/coderdojo-japan/dojopaas/issues/249"
    exit 1
  end
  
  issue_url = ARGV[0]
  
  # 環境変数チェック
  unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
    puts "エラー: さくらのクラウドAPIトークンが設定されていません"
    puts "以下の環境変数を設定してください:"
    puts "  export SACLOUD_ACCESS_TOKEN=xxx"
    puts "  export SACLOUD_ACCESS_TOKEN_SECRET=xxx"
    exit 1
  end
  
  # 実行
  initializer = ServerInitializer.new(issue_url, options)
  initializer.run
end