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

$ ls test/
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

### Phase 1: 初期実装（PR #250 - 実施中）

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

**期限**: 2024年1月（PR #250）

### Phase 2: 頻用コマンドの追加

**目的**: よく使われるスクリプトをRakeタスク化

```ruby
namespace :server do
  desc "Initialize (delete and recreate) a server - ⚠️ DESTRUCTIVE"
  task :initialize, [:ip] => [:confirm_destructive] do |t, args|
    sh "ruby scripts/initialize_server.rb --delete #{args[:ip]} --force"
  end
  
  desc "Check server status"
  task :status, [:name] do |t, args|
    sh "ruby test/check_server_status.rb #{args[:name]}"
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
    sh "ruby test/find_resources.rb #{pattern}"
  end
  
  desc "Verify server setup and connectivity"
  task :verify, [:ip] => [:validate_ip] do |t, args|
    sh "ruby test/verify_server_setup.rb #{args[:ip]}"
  end
end
```

**スコープ**:
- 日常的に使用される5-7個のタスク
- 破壊的操作への確認プロンプト追加
- 基本的な依存関係の定義

**期限**: 2024年2月

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

### Phase 1（現在のPR）
- [ ] 基本的なRakefile作成
- [ ] server:find_for_initializationタスク実装
- [ ] IPAddr検証の組み込み
- [ ] GitHub Actionsとの統合
- [ ] 基本的なヘルプ機能

### Phase 2
- [ ] deploy名前空間の追加
- [ ] test名前空間の追加
- [ ] 依存関係の定義
- [ ] 環境変数の管理

### Phase 3
- [ ] すべてのスクリプトの分類
- [ ] 内部ライブラリの区別
- [ ] メンテナンスタスクの追加
- [ ] 高度なヘルパー機能

### Phase 4
- [ ] 自動ドキュメント生成
- [ ] タスクの使用統計
- [ ] パフォーマンス最適化

## 📝 関連ドキュメント

- [GitHub Actions自動化計画](./plan_github_action_initialize.md)
- [サーバー初期化スクリプト計画](./plan_initialize_server.md)
- [Rake公式ドキュメント](https://ruby.github.io/rake/)

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