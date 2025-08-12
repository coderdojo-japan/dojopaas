# Rakefile移行計画：DojoPaaSスクリプトの段階的統合

## 📝 概要

DojoPaaSプロジェクトの全Rubyスクリプトを段階的にRakefileに統合し、新規開発者にとって分かりやすい「**実行可能操作のカタログ**」を構築する計画。

## 🎯 目的と価値

### 現状の課題

新規開発者がプロジェクトに参加した際の問題：
```bash
# 新規開発者の体験
$ ls scripts/
deploy.rb  initialize_server.rb  sakura_server_user_agent.rb  smart_wait_helper.rb
# 「これ何？実行していいの？引数は？」

$ ls scripts/utils/
check_server_status.rb  find_resources.rb  test_regex_patterns.rb  ...
# 「テスト？ツール？どっち？」
```

**学習時間**: 1-2時間（README熟読 + 各スクリプト調査）

### Rakefile導入後の価値

```bash
$ rake -T
rake server:find[input]              # Find server information by IP address
rake server:initialize[ip]          # Initialize (delete and recreate) a server
rake deploy:production              # Deploy new servers from servers.csv
rake test:verify[ip]                # Verify server setup and connectivity
# 即座に利用可能な操作が分かる！
```

**学習時間**: 1分（`rake -T`実行のみ）

## 🏗️ アーキテクチャ設計

### 最終形のビジョン

```
Rakefile                        # 📖 実行可能な操作のカタログ
├── Default Tasks
│   ├── rake -T                # すべての操作を一覧
│   └── rake help              # 詳細なヘルプ
├── Server Management
│   ├── rake server:find       # サーバー情報検索
│   ├── rake server:initialize # サーバー初期化
│   └── rake server:status     # ステータス確認
├── Deployment
│   ├── rake deploy:production # 本番デプロイ
│   └── rake deploy:check      # デプロイ前チェック
├── Testing & Verification
│   ├── rake test:all          # 全テスト実行
│   ├── rake test:verify       # サーバー検証
│   └── rake test:find         # リソース検索
└── Maintenance
    ├── rake maintenance:cleanup # クリーンアップ
    └── rake maintenance:audit   # 監査ログ
```

## 📋 段階的移行計画

### Phase 1: 初期実装（✅ 完了）

**目的**: 最小限の実装でGitHub Actions統合を実現

```ruby
# Rakefile - 最小限の実装
namespace :server do
  desc "Find server by IP for initialization request"
  task :find_for_initialization, [:ip] do |t, args|
    require 'ipaddr'
    
    ip = args[:ip] || ENV['IP_ADDRESS']
    abort "IP address required" unless ip
    
    # Ruby IPAddrで検証（セキュリティ層）
    begin
      validated_ip = IPAddr.new(ip).to_s
    rescue IPAddr::InvalidAddressError
      abort "Invalid IP address: #{ip}"
    end
    
    sh "ruby scripts/initialize_server.rb --find #{validated_ip}"
  end
end
```

**スコープ**:
- ✅ サーバー初期化依頼の自動応答のみ
- ✅ IPAddr検証によるセキュリティ強化
- ✅ GitHub Actions統合

**実装完了**: 2025年8月11日

#### 実装内容

##### 1. 統一命名パターンとDRY原則
```ruby
# 統一パターン: find_by_[method]
task :find_by_ip       # IPアドレスで検索（GitHub Actionsで使用）
task :find_by_issue    # Issue URLで検索
task :find_by_name     # サーバー名で検索
```

**メリット**:
- 一貫性のある命名パターン
- 新しい検索メソッドの追加が容易
- 学習コストの低減（パターンを覚えれば予測可能）

##### 2. 依存関係ベースのタスク管理
```ruby
# API認証を前提条件として追加
task :find_for_initialization, [:ip] => [:check_api_credentials, :validate_env]
```
- 複数タスクから参照されても各前提条件は一度だけ実行
- 失敗の早期検出と即座の停止
- 依存グラフによる自動的な順序決定

##### 3. インクリメンタル実行サポート
```ruby
def save_task_status(task_name, status)
  FileUtils.mkdir_p('tmp/rake_status')
  File.write(status_file_for(task_name), JSON.pretty_generate({
    task: task_name,
    status: status,
    timestamp: Time.now.iso8601
  }))
end
```
- `prepare_deletion` → `execute_deletion` → `create_empty_commit`の連鎖
- 各ステップの結果を保存し、次のステップで検証
- 中断からの再開が可能

##### 4. 完全なサーバー初期化フロー
```ruby
desc "サーバー初期化の完全なフロー（Issue番号必須）"
task :initialize, [:ip, :issue_number] do |t, args|
  Rake::Task['server:prepare_deletion'].invoke(ip)
  Rake::Task['server:execute_deletion'].invoke(ip, 'true')
  Rake::Task['server:create_empty_commit'].invoke(issue_number)
end
```

##### 5. GitHub Actions統合の改善
```yaml
# 改善前
ruby scripts/initialize_server.rb --delete $IP --force

# 改善後（Rakeタスクによる標準化）
bundle exec rake server:initialize[$IP,$ISSUE_NUMBER]
```

##### 6. テスト結果
```bash
$ bundle exec rake spec
77 examples, 0 failures  # 全テスト成功
```

### Phase 2: 頻用コマンドの追加（🚧 進行中）

**目的**: よく使われるスクリプトをRakeタスク化

```ruby
namespace :server do
  desc "Initialize (delete and recreate) a server - ⚠️ DESTRUCTIVE"
  task :initialize, [:ip] => [:confirm_destructive] do |t, args|
    sh "ruby scripts/initialize_server.rb --delete #{args[:ip]} --force"
  end
  
  desc "Check server status"
  task :status, [:name] do |t, args|
    sh "ruby scripts/utils/check_server_status.rb #{args[:name]}"
  end
end

namespace :deploy do
  desc "Deploy servers from servers.csv to production"
  task :production => [:environment, :validate_csv] do
    sh "bundle exec ruby scripts/deploy.rb"
  end
  
  task :validate_csv do
    sh "bundle exec rake test"  # 既存のCSVテスト
  end
end

namespace :test do
  desc "Find test resources by pattern"
  task :find_resources, [:pattern] do |t, args|
    pattern = args[:pattern] || ""
    sh "ruby scripts/utils/find_resources.rb #{pattern}"
  end
  
  desc "Verify server setup and connectivity"
  task :verify, [:ip] => [:validate_ip] do |t, args|
    sh "ruby scripts/utils/verify_server_setup.rb #{args[:ip]}"
  end
end
```

**スコープ**:
- 日常的に使用される5-7個のタスク
- 破壊的操作への確認プロンプト追加
- 基本的な依存関係の定義

**実装状況**: 2025年8月11日時点

#### 実装済みタスク（2025年8月11日更新）
```bash
# サーバー検索（統一命名パターン: find_by_[method]）
rake server:find_by_ip[ip]              # IPアドレスでサーバーを検索
rake server:find_by_issue[issue_url]    # Issue URLでサーバーを検索
rake server:find_by_name[name]          # サーバー名でサーバーを検索
rake server:list                        # 現在稼働中のサーバー一覧を表示（新規追加）

# サーバー削除管理
rake server:prepare_deletion[ip]        # サーバー削除の準備
rake server:execute_deletion[ip,force]  # サーバーを削除
rake server:create_empty_commit[issue]  # 削除後の空コミット作成
rake server:initialize[ip,issue_number] # 完全な初期化フロー

# 並列実行（追加実装）
rake parallel:check_all                 # 複数サーバーの状態を並列チェック

# クリーンタスク（追加実装）
rake clear_status                       # ステータスファイルをクリア
rake clean                              # 一時ファイルを削除
rake clobber                           # 生成ファイルをすべて削除
```

#### 追加機能（2025年8月11日）
- **テスト用サーバー保護機能**: `SAFE_TEST_SERVERS`定数で管理
- **サーバー一覧表示**: gh-pagesブランチから実データ取得
- **定数の一元管理**: `SakuraServerUserAgent::INSTANCES_CSV_URL`
- **標準ライブラリの整理**: `net/http`, `uri`, `csv`を冒頭で一括require

#### 未実装タスク
- `rake server:status[name]` - サーバーステータス確認
- `rake deploy:production` - 本番デプロイ（既存CI/CDで動作中）
- `rake test:verify[ip]` - サーバーセットアップ検証

**期限**: 2025年2月

### Phase 3: 完全統合

**目的**: すべてのスクリプトをカタログ化

```ruby
# 共通ヘルパーモジュール
module RakeHelpers
  def validate_ip!(ip)
    require 'ipaddr'
    IPAddr.new(ip).to_s
  rescue IPAddr::InvalidAddressError
    abort "❌ Invalid IP: #{ip}"
  end
  
  def validate_issue_url!(url)
    unless url =~ %r{^https://github\.com/coderdojo-japan/dojopaas/issues/\d+$}
      abort "❌ Invalid Issue URL: #{url}"
    end
    url
  end
  
  def confirm_destructive_action!
    return if ENV['FORCE'] == 'true'
    
    print "⚠️  This is a destructive action. Continue? (yes/no): "
    response = STDIN.gets.chomp
    abort "Cancelled" unless response.downcase == 'yes'
  end
end

# 内部ライブラリの明示
namespace :internal do
  desc "[INTERNAL] Sakura API client library - not for direct execution"
  task :sakura_api do
    abort "This is a library file, not meant to be executed directly"
  end
  
  desc "[INTERNAL] Smart wait helper module"
  task :smart_wait do
    abort "This is a helper module, not meant to be executed directly"
  end
end

# メンテナンスタスク
namespace :maintenance do
  desc "Clean up orphaned resources"
  task :cleanup => [:environment, :dry_run_warning] do
    sh "ruby scripts/cleanup_orphaned_resources.rb"
  end
  
  desc "Generate audit report"
  task :audit do
    sh "ruby scripts/generate_audit_report.rb"
  end
end
```

**スコープ**:
- すべてのスクリプトの分類と整理
- 内部ライブラリの明示的な区別
- 高度なヘルパー機能の実装

**期限**: 2024年3月

### Phase 4: ドキュメント生成

**目的**: Rakefileから自動的にドキュメント生成

```ruby
namespace :docs do
  desc "Generate task documentation in Markdown"
  task :generate do
    output = "# DojoPaaS Available Tasks\n\n"
    output += "Generated at: #{Time.now}\n\n"
    
    # Rakeタスクを解析してMarkdown生成
    Rake.application.tasks.each do |task|
      next if task.name.start_with?('internal:')
      output += "## `rake #{task.name}`\n"
      output += "#{task.comment}\n\n" if task.comment
    end
    
    File.write('docs/TASKS.md', output)
    puts "📝 Documentation generated: docs/TASKS.md"
  end
end
```

**期限**: 2024年4月

## 🔒 セキュリティ設計

### 中央集権的な入力検証

すべての入力検証をRakefileで一元管理：

```ruby
# lib/rake_security.rb
module RakeSecurity
  SAKURA_IP_RANGES = [
    IPAddr.new("153.127.0.0/16"),  # 石狩第二
    IPAddr.new("163.43.0.0/16"),   # 東京
    IPAddr.new("133.242.0.0/16"),  # 大阪
  ].freeze
  
  def validate_sakura_ip!(ip)
    ip_addr = IPAddr.new(ip)
    
    # プライベートIP除外
    raise "Private IP not allowed" if ip_addr.private?
    
    # さくらクラウド範囲チェック
    unless SAKURA_IP_RANGES.any? { |range| range.include?(ip_addr) }
      raise "IP not in Sakura Cloud range"
    end
    
    ip_addr.to_s
  end
end
```

## 📊 成功指標

| 指標 | 現在 | 目標（Phase 4後） |
|------|------|------------------|
| **新規開発者の学習時間** | 1-2時間 | 5分以内 |
| **実行可能操作の発見性** | 低（要調査） | 高（rake -T） |
| **スクリプトの重複** | あり | なし |
| **セキュリティ検証** | 分散 | 中央集権 |
| **ドキュメント同期** | 手動 | 自動生成 |

## 🎯 重要な設計原則

### 1. Progressive Enhancement（段階的改善）
- 小さく始めて徐々に拡大
- 各フェーズで価値を提供
- 後方互換性を維持

### 2. Self-Documenting（自己文書化）
- タスク名が操作を説明
- `desc`で詳細な説明
- `rake -T`で一覧表示

### 3. Fail-Safe Design（フェイルセーフ設計）
- 破壊的操作には確認
- 入力検証を必須化
- エラーメッセージを明確に

### 4. DRY (Don't Repeat Yourself)
- 共通処理はヘルパーに
- 設定は一箇所で管理
- 重複コードを排除

## 🚀 実装チェックリスト

### Phase 1（✅ 完了）
- [x] 基本的なRakefile作成
- [x] server:find_for_initializationタスク実装
- [x] IPAddr検証の組み込み
- [x] GitHub Actionsとの統合
- [x] 基本的なヘルプ機能
- [x] 依存関係管理の実装
- [x] インクリメンタル実行サポート
- [x] エラーハンドリングの強化

### Phase 2（🚧 進行中）
- [ ] deploy名前空間の追加
- [ ] test名前空間の追加
- [x] 依存関係の定義（Phase 1で実装済み）
- [x] 環境変数の管理（check_api_credentialsで実装）
- [x] 並列実行サポート（multitask実装済み）
- [x] クリーンタスク実装

### Phase 3
- [ ] すべてのスクリプトの分類
- [ ] 内部ライブラリの区別
- [ ] メンテナンスタスクの追加
- [ ] 高度なヘルパー機能

### Phase 4
- [ ] 自動ドキュメント生成
- [ ] タスクの使用統計
- [ ] パフォーマンス最適化

## 📊 パフォーマンスへの影響

### 起動オーバーヘッド（実測値）
- 単純なタスク: 無視できる程度（< 100ms）
- 複雑な依存関係: 約200-500ms
- Rails環境（該当なし）: 8-10秒

### トレードオフ
起動時間のわずかな増加と引き換えに以下を獲得：
- **堅牢性**: 依存関係の自動管理
- **保守性**: 自己文書化されたタスク
- **拡張性**: 新しいタスクの追加が容易
- **チーム協働**: 標準化された操作

## 📝 関連ドキュメント

- [GitHub Actions自動化計画](./plan_github_action_initialize.md)
- [サーバー初期化スクリプト計画](./plan_initialize_server.md)
- [Rake公式ドキュメント](https://ruby.github.io/rake/)
- [Opus 4.1によるRake研究結果](https://claude.ai/public/artifacts/ac5f7609-1259-429a-a292-1fa2fabc3710)

## 🎉 期待される成果

**Before（現在）**:
```bash
# 新規開発者
"どのスクリプトを使えばいい？"
"引数は何？"
"実行して大丈夫？"
# → 不安と時間の浪費
```

**After（完全移行後）**:
```bash
$ rake -T
# すべての操作が一目瞭然！
$ rake -D server:find
# 詳細な説明も即座に確認
# → 自信を持って作業開始
```

---

**この計画により、DojoPaaSは新規開発者にとって親しみやすく、既存開発者にとって効率的なプロジェクトへと進化します。**