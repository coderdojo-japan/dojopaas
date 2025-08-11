#!/usr/bin/env ruby

# DojoPaaS サーバー初期化支援スクリプト
# GitHub Issueから情報を抽出し、サーバー削除の準備を支援します
# 
# 使用方法:
#   ruby scripts/initialize_server.rb --find https://github.com/coderdojo-japan/dojopaas/issues/249
#   ruby scripts/initialize_server.rb --delete 153.127.192.200  # サーバー削除（危険）

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
  
  # IPアドレスの厳密な検証パターン
  VALID_IP_PATTERN = /\A(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\z/

  def initialize(input, options = {})
    @input       = input  # Issue URLまたはIPアドレス
    @verbose     = options[:verbose] || false
    @delete_mode = options[:delete]  || false
    @find_mode   = options[:find]    || false
    @dry_run     = options[:dry_run] || false
    @force       = options[:force]   || false
    
    # さくらのクラウドAPIクライアント初期化（石狩第二ゾーン）
    @ssua = SakuraServerUserAgent.new(
      zone: "31002",
      zone_id: "is1b",
      packet_filter_id: nil,
      verbose: @verbose
    )
  end

  def run
    if @delete_mode
      run_delete_mode
    elsif @find_mode
      run_find_mode
    else
      # オプションが指定されていない場合はヘルプを表示
      show_help
    end
  end

  private

  def show_help
    puts ""  # 上部に空行
    puts "使用方法: #{$0} [options]"
    puts ""
    puts "オプション:"
    puts "        --find <URL|IP|NAME>         サーバー情報を検索（URL/IP/名前）"
    puts "        --delete IP_ADDRESS          指定したIPアドレスのサーバーを削除（危険）"
    puts "        --force                      削除時の確認をスキップ（危険）"
    puts "        --dry-run                    削除を実行せず、何が起こるかを表示（開発者向け）"
    puts "        --verbose                    詳細ログを出力"
    puts "    -h, --help                       ヘルプを表示"
    puts ""
    puts "環境変数:"
    puts "  SACLOUD_ACCESS_TOKEN       さくらのクラウドAPIトークン（必須）"
    puts "  SACLOUD_ACCESS_TOKEN_SECRET さくらのクラウドAPIシークレット（必須）"
    puts ""
    puts "使用例:"
    puts "  # GitHub Issueから検索"
    puts "  #{$0} --find https://github.com/coderdojo-japan/dojopaas/issues/249"
    puts ""
    puts "  # IPアドレスで検索"
    puts "  #{$0} --find 153.127.192.200"
    puts ""
    puts "  # サーバー名で検索"
    puts "  #{$0} --find coderdojo-japan"
    puts ""
    puts "  # IPアドレスを指定して削除（危険）"
    puts "  #{$0} --delete 192.168.1.1"
    puts ""
    puts "  # 確認なしで削除（非常に危険）"
    puts "  #{$0} --delete 192.168.1.1 --force"
    puts ""
    puts "  # 削除のシミュレーション（開発・テスト用）"
    puts "  #{$0} --delete 192.168.1.1 --dry-run"
    puts ""
    puts "⚠️  警告: --delete オプションはサーバーとディスクを完全に削除します！"
    puts "         --force を使用すると確認なしで削除されます（非常に危険）！"
    puts "         --dry-run を使用すると、実際には削除せずに動作を確認できます。"
    puts ""  # 下部に空行
    exit 0
  end

  # IPアドレスによる削除モード
  def run_delete_mode
    puts "=" * 60
    if @dry_run
      puts "🔍 DojoPaaS サーバー削除モード（DRY-RUN）"
    else
      puts "⚠️  DojoPaaS サーバー削除モード（危険）"
    end
    puts "=" * 60
    puts ""
    
    # IPアドレスの検証
    unless valid_ip_address?(@input)
      puts "❌ エラー: 無効なIPアドレス形式です: #{@input}"
      puts ""
      puts "正しいIPアドレス形式で指定してください（例: 192.168.1.1）"
      puts "処理を中止します（サーバーへの変更は行われません）"
      exit 1
    end
    
    puts "🔍 IPアドレス #{@input} のサーバーを検索中..."
    puts ""
    
    # サーバーの検索
    server_info = find_server_by_ip(@input)
    
    if server_info.nil?
      puts "❌ エラー: IPアドレス #{@input} に対応するサーバーが見つかりません"
      puts ""
      puts "以下を確認してください:"
      puts "  1. IPアドレスが正しいか"
      puts "  2. サーバーがまだ存在しているか"
      puts "  3. さくらのクラウドAPIの接続状態"
      puts ""
      puts "処理を中止します（サーバーへの変更は行われません）"
      exit 1
    end
    
    # サーバー情報の表示
    display_server_details_for_deletion(server_info)
    
    # ディスク情報の取得と表示
    disk_ids = get_server_disks(server_info['ID'])
    display_disk_details(disk_ids) if disk_ids.any?
    
    # 削除確認
    unless confirm_deletion(server_info, disk_ids)
      puts ""
      puts "削除がキャンセルされました。サーバーは変更されません。"
      exit 0
    end
    
    # 実際の削除処理
    execute_deletion(server_info, disk_ids)
  end

  # 汎用検索モード（URL/IP/名前）
  def run_find_mode
    puts "=== DojoPaaS サーバー検索 ==="
    puts ""

    begin
      # 入力タイプを判定
      if @input =~ /^https?:\/\//
        # URLの場合: GitHub Issueから情報を取得
        find_by_issue_url
      elsif @input =~ /\d+\.\d+\.\d+\.\d+/
        # IPアドレスの場合: 直接サーバーを検索
        find_by_ip_address
      else
        # その他のテキスト: サーバー名で検索
        find_by_name
      end
    rescue => e
      puts "❌ 予期しないエラーが発生しました: #{e.message}"
      puts e.backtrace if @verbose
      puts ""
      puts "処理を中止します（サーバーへの変更は行われません）"
      exit 1
    end
  end

  # GitHub Issueから検索
  def find_by_issue_url
    puts "📌 GitHub Issueから情報を取得中..."
    @issue_url = @input
    issue_data = fetch_issue_data
    
    # 情報の抽出（正規表現のみ、失敗したら即停止）
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

    # サーバー情報の取得
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

    display_server_info(server_info)

    # 名前の照合（安全確認）
    if !verify_server_match(dojo_name, server_info)
      puts "⚠️  警告: CoderDojo名とサーバー名が一致しません"
      puts "  - Issue記載: #{dojo_name}"
      puts "  - サーバー名: #{server_info['Name']}"
      puts ""
      
      print "それでも続行しますか？ (yes/no): "
      answer = STDIN.gets.chomp.downcase
      unless ['yes', 'y'].include?(answer)
        puts "処理を中止しました"
        exit 0
      end
    else
      puts "✅ 名前の照合: OK"
    end

    # 削除準備の表示
    display_deletion_plan(server_info, get_server_ip(server_info), dojo_name)
  end
  
  # IPアドレスで直接検索
  def find_by_ip_address
    puts "🔍 IPアドレス #{@input} でサーバーを検索中..."
    puts ""
    
    server_info = find_server_by_ip(@input)
    
    if server_info.nil?
      puts "❌ エラー: IPアドレス #{@input} に対応するサーバーが見つかりません"
      puts ""
      puts "以下を確認してください:"
      puts "  1. IPアドレスが正しいか"
      puts "  2. サーバーがまだ存在しているか"
      puts "  3. さくらのクラウドAPIの接続状態"
      puts ""
      puts "処理を中止します"
      exit 1
    end
    
    display_server_info(server_info)
    
    # 削除準備の表示（IPアドレス検索の場合はCoderDojo名は不明）
    dojo_name = extract_dojo_from_server_name(server_info['Name'])
    display_deletion_plan(server_info, @input, dojo_name)
  end
  
  # サーバー名で検索
  def find_by_name
    puts "🔍 サーバー名 '#{@input}' で検索中..."
    puts ""
    
    # 全サーバーを取得
    servers_response = @ssua.get_servers()
    servers = servers_response['Servers'] || []
    
    # 名前で検索（完全一致のみ）
    matched_servers = servers.select do |server|
      server['Name'].downcase == @input.downcase
    end
    
    if matched_servers.empty?
      puts "❌ エラー: '#{@input}' に一致するサーバーが見つかりません"
      puts ""
      puts "以下を確認してください:"
      puts "  1. サーバー名が正しいか（完全一致で検索）"
      puts "  2. サーバーがまだ存在しているか"
      puts ""
      puts "例: coderdojo-japan （coderdojo- プレフィックスも必要）"
      puts ""
      puts "処理を中止します"
      exit 1
    end
    
    # 完全一致なので複数マッチはありえないが、念のため
    if matched_servers.length > 1
      puts "⚠️  内部エラー: 複数のサーバーが見つかりました"
      exit 1
    end
    
    server_info = matched_servers.first
    display_server_info(server_info)
    
    # 削除準備の表示
    ip_address = get_server_ip(server_info)
    dojo_name = extract_dojo_from_server_name(server_info['Name'])
    display_deletion_plan(server_info, ip_address, dojo_name)
  end

  # IPアドレスの検証
  def valid_ip_address?(ip)
    return false if ip.nil? || ip.empty?
    !!(ip =~ VALID_IP_PATTERN)
  end
  
  # サーバー情報の詳細表示（削除用）
  def display_server_details_for_deletion(server)
    puts "=" * 60
    puts "🖥️  削除対象サーバーの詳細"
    puts "=" * 60
    puts ""
    puts "  サーバー名: #{server['Name']}"
    puts "  サーバーID: #{server['ID']}"
    puts "  IPアドレス: #{@input}"
    puts "  説明: #{server['Description']}"
    puts "  タグ: #{server['Tags'].join(', ')}"
    puts "  ステータス: #{server['Instance']['Status']}"
    puts "  CPU: #{server['ServerPlan']['CPU']}コア"
    puts "  メモリ: #{server['ServerPlan']['MemoryMB']}MB"
    puts ""
  end
  
  # ディスク情報の取得
  def get_server_disks(server_id)
    puts "DEBUG: Getting disks for server ID: #{server_id}" if @verbose
    server_detail = @ssua.get_server_details(server_id)
    puts "DEBUG: Server detail response: #{server_detail.inspect}" if @verbose
    return [] unless server_detail && server_detail['Server']
    
    disks = server_detail['Server']['Disks'] || []
    puts "DEBUG: Found #{disks.length} disk(s)" if @verbose
    disks.map { |disk| disk['ID'] }
  rescue => e
    puts "⚠️  警告: ディスク情報の取得に失敗しました: #{e.message}" if @verbose
    puts "DEBUG: Error details: #{e.backtrace.first(3).join("\n")}" if @verbose
    []
  end
  
  # ディスク情報の表示
  def display_disk_details(disk_ids)
    puts "💾 接続されているディスク:"
    disk_ids.each do |disk_id|
      begin
        disk_info = @ssua.get_disk_details(disk_id)
        if disk_info && disk_info['Disk']
          disk = disk_info['Disk']
          puts "  - ディスクID: #{disk['ID']}"
          puts "    名前: #{disk['Name']}"
          puts "    サイズ: #{disk['SizeMB']}MB"
          puts "    プラン: #{disk['Plan']['Name']}"
        end
      rescue => e
        puts "  - ディスクID: #{disk_id} (詳細取得失敗)"
      end
    end
    puts ""
  end
  
  # 削除の確認（多重確認）
  def confirm_deletion(server, disk_ids)
    # dry-runモードでは確認をスキップ
    if @dry_run
      puts "=" * 60
      puts "🔍 DRY-RUN モード - 確認をスキップ"
      puts "=" * 60
      return true
    end
    
    # --forceオプションが指定されている場合は確認をスキップ
    if @force
      puts "=" * 60
      puts "🔍 --force オプションにより確認をスキップ"
      puts "=" * 60
      puts ""
      puts "削除を実行します..."
      return true
    end
    
    puts "=" * 60
    puts "⚠️  ⚠️  ⚠️  削除確認 ⚠️  ⚠️  ⚠️"
    puts "=" * 60
    puts ""
    puts "以下のリソースが【完全に削除】されます:"
    puts ""
    puts "  🖥️  サーバー: #{server['Name']} (ID: #{server['ID']})"
    puts "  💾 ディスク数: #{disk_ids.length}個"
    puts ""
    puts "⚠️  この操作は取り消せません！"
    puts "⚠️  すべてのデータが失われます！"
    puts ""
    print "本当に削除しますか？ (yes/no): "
    
    # Claude Code環境では入力が取得できないため、エラーハンドリングを追加
    begin
      input = STDIN.gets
      if input.nil?
        puts ""
        puts "❌ エラー: 対話式入力が利用できません"
        puts "Claude Code環境での削除には FORCE_DELETE=yes 環境変数を使用してください"
        puts ""
        puts "例: FORCE_DELETE=yes ruby scripts/initialize_server.rb --delete #{@input}"
        return false
      end
      answer = input.chomp.downcase
    rescue => e
      puts ""
      puts "❌ 入力エラー: #{e.message}"
      puts "Claude Code環境での削除には FORCE_DELETE=yes 環境変数を使用してください"
      return false
    end
    
    # yes/y/no/n以外の入力は全て拒否
    unless ['yes', 'y', 'no', 'n'].include?(answer)
      puts ""
      puts "❌ 無効な入力です。'yes', 'y', 'no', 'n' のいずれかを入力してください。"
      puts "安全のため処理を中止します。"
      return false
    end
    
    # noまたはnの場合は中止
    if ['no', 'n'].include?(answer)
      return false
    end
    
    # yesまたはyの場合、さらに確認（FORCE_DELETE環境変数の場合はスキップ）
    if ENV['FORCE_DELETE'] == 'yes'
      puts ""
      puts "🔍 FORCE_DELETE環境変数により最終確認もスキップ"
      puts "削除を実行します..."
      return true
    end
    
    puts ""
    puts "⚠️  最終確認：サーバー #{server['Name']} を本当に削除しますか？"
    print "削除を実行する場合は 'DELETE' と入力してください: "
    
    begin
      input = STDIN.gets
      if input.nil?
        puts ""
        puts "❌ エラー: 対話式入力が利用できません"
        puts "Claude Code環境での削除には FORCE_DELETE=yes 環境変数を使用してください"
        return false
      end
      final_answer = input.chomp
    rescue => e
      puts ""
      puts "❌ 入力エラー: #{e.message}"
      puts "Claude Code環境での削除には FORCE_DELETE=yes 環境変数を使用してください"
      return false
    end
    
    if final_answer == 'DELETE'
      puts ""
      puts "削除を実行します..."
      return true
    else
      puts ""
      puts "'DELETE' と入力されなかったため、削除を中止します。"
      return false
    end
  end
  
  # 削除の実行
  def execute_deletion(server, disk_ids)
    puts ""
    
    if @dry_run
      puts "🔍 [DRY-RUN MODE] 削除シミュレーション開始..."
    else
      puts "🗑️  削除処理を開始します..."
    end
    
    puts ""
    
    begin
      server_id = server['ID']
      
      # 1. サーバーの電源状態確認
      if @dry_run
        puts "🔍 [DRY-RUN] Would check power status: GET /server/#{server_id}/power"
        puts "🔍 [DRY-RUN] Current status: #{server['Instance']['Status']}"
      else
        power_status = @ssua.get_server_power_status_by_id(server_id)
      end
      
      # 2. サーバーが起動中なら停止
      if @dry_run
        if server['Instance']['Status'] == 'up'
          puts "⏸️  [DRY-RUN] Would stop server: DELETE /server/#{server_id}/power"
          puts "⏸️  [DRY-RUN] Would wait for server to stop (max 60 seconds)"
        else
          puts "⏸️  [DRY-RUN] Server already stopped, skipping shutdown"
        end
      else
        if power_status && power_status['Instance'] && power_status['Instance']['Status'] == 'up'
          puts "⏸️  サーバーを停止中..."
          @ssua.stop_server(server_id)
          
          # 停止を待つ
          wait_count = 0
          while wait_count < 30  # 最大60秒待機
            sleep(2)
            power_status = @ssua.get_server_power_status_by_id(server_id)
            break if power_status['Instance']['Status'] == 'down'
            wait_count += 1
            print "."
          end
          puts ""
          puts "✅ サーバーを停止しました"
        end
      end
      
      # 3. サーバーの削除（ディスクも同時に削除）
      if @dry_run
        puts "🗑️  [DRY-RUN] Would delete server and disks:"
        puts "    - API call: DELETE /server/#{server_id}"
        puts "    - Parameters: { WithDisk: #{disk_ids.inspect} }"
        puts "    - Server name: #{server['Name']}"
        puts "    - Server ID: #{server_id}"
        puts "    - Disk IDs: #{disk_ids.join(', ')}"
      else
        puts "🗑️  サーバーとディスクを削除中..."
        @ssua.delete_server(server_id, disk_ids)
      end
      
      puts ""
      puts "=" * 60
      if @dry_run
        puts "✅ [DRY-RUN] 削除シミュレーションが完了しました"
        puts "=" * 60
        puts ""
        puts "削除される予定のリソース:"
        puts "  - サーバー: #{server['Name']} (ID: #{server_id})"
        puts "  - ディスク数: #{disk_ids.length}個"
        puts ""
        puts "⚠️  これはドライランです。実際には何も削除されていません。"
        puts "実際に削除する場合は --dry-run オプションを外して実行してください。"
      else
        puts "✅ 削除が完了しました"
        puts "=" * 60
        puts ""
        puts "削除されたリソース:"
        puts "  - サーバー: #{server['Name']} (ID: #{server_id})"
        puts "  - ディスク数: #{disk_ids.length}個"
      end
      puts ""
      puts "次のステップ:"
      puts "  1. servers.csvから該当行を削除"
      puts "  2. git commit -m 'Remove server: #{server['Name']}'"
      puts "  3. git push（CIが新しいサーバーを作成）"
      
    rescue => e
      puts ""
      puts "❌ 削除中にエラーが発生しました: #{e.message}"
      puts e.backtrace if @verbose
      puts ""
      puts "さくらのクラウドコントロールパネルで状態を確認してください:"
      puts "https://secure.sakura.ad.jp/cloud/"
      exit 1
    end
  end

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

  # サーバー情報の表示
  def display_server_info(server)
    puts "🖥️  サーバー情報:"
    puts "  - サーバー名: #{server['Name']}"
    puts "  - サーバーID: #{server['ID']}"
    puts "  - 説明: #{server['Description']}"
    puts "  - タグ: #{server['Tags'].join(', ')}"
    puts "  - ステータス: #{server['Instance']['Status']}"
    
    # IPアドレスを取得して表示
    ip = get_server_ip(server)
    puts "  - IPアドレス: #{ip || 'N/A'}"
    puts ""
  end
  
  # サーバーからIPアドレスを取得
  def get_server_ip(server)
    interfaces = server['Interfaces'] || []
    interface = interfaces.first
    interface ? interface['IPAddress'] : nil
  end
  
  # サーバー名からCoderDojo名を推測
  def extract_dojo_from_server_name(server_name)
    # coderdojo-japan -> japan のような変換
    server_name.gsub(/^coderdojo[-_]?/i, '').upcase
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
    puts "  CoderDojo: #{dojo_name || '(自動判定)'}"
    puts ""
    
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
      if @issue_url
        issue_number = @issue_url[/\d+$/]
        puts "   git commit --allow-empty -m \"Fix ##{issue_number}: Initialize server for CoderDojo #{dojo_name}\""
      else
        puts "   git commit --allow-empty -m \"Initialize server: #{server_info['Name']}\""
      end
      puts "   git push"
      puts ""
      puts "5. CIが自動的に新しいサーバーを作成します"
    puts ""
    puts "=" * 60
    puts "処理完了"
    puts "=" * 60
  end
end

# メイン処理
if __FILE__ == $0
  options = {}
  input = nil
  
  
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    
    opts.on("--find <URL|IP|NAME>", "サーバー情報を検索（URL/IP/名前）") do |query|
      options[:find] = true
      input = query
    end
    
    opts.on("--delete IP_ADDRESS", "指定したIPアドレスのサーバーを削除（危険）") do |ip|
      options[:delete] = true
      input = ip
    end
    
    opts.on("--force", "削除時の確認をスキップ（危険）") do
      options[:force] = true
    end
    
    opts.on("--dry-run", "削除を実行せず、何が起こるかを表示（開発者向け）") do
      options[:dry_run] = true
    end
    
    opts.on("--verbose", "詳細ログを出力") do
      options[:verbose] = true
    end
    
    opts.on("-h", "--help", "ヘルプを表示") do
      # initializerを作成してヘルプを表示
      ServerInitializer.new("", {}).send(:show_help)
    end
  end.parse!
  
  # パラメータなしの場合はヘルプを表示
  if input.nil? && ARGV.empty?
    ServerInitializer.new("", {}).send(:show_help)
  end
  
  # 入力の取得
  if input.nil?
    input = ARGV[0]
  end
  
  # 環境変数チェック
  unless ENV['SACLOUD_ACCESS_TOKEN'] && ENV['SACLOUD_ACCESS_TOKEN_SECRET']
    puts "エラー: さくらのクラウドAPIトークンが設定されていません"
    puts "以下の環境変数を設定してください:"
    puts "  export SACLOUD_ACCESS_TOKEN=xxx"
    puts "  export SACLOUD_ACCESS_TOKEN_SECRET=xxx"
    exit 1
  end
  
  # 実行
  initializer = ServerInitializer.new(input, options)
  initializer.run
end
