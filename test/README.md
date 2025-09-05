# テストディレクトリ構成

## ディレクトリ構造

```
test/
├── README.md                  # このファイル
├── csv_test.rb               # CSVフォーマットのバリデーションテスト
├── ip_validation_test.rb     # IPアドレス検証のテスト
└── integration/              # 統合テスト・実際のAPI呼び出しテスト
    ├── test_regex_patterns.rb        # 正規表現パターンのテスト
    ├── test_server_with_notes.rb     # スタートアップスクリプト実行テスト
    ├── test_with_packet_filter.rb    # パケットフィルター適用テスト
    └── test_with_startup_script.rb   # スタートアップスクリプトテスト
```

## テストの種類

### ユニットテスト（`test/`直下）

- **csv_test.rb**: `servers.csv`のフォーマットを検証
  - ヘッダーの存在確認
  - 必須フィールドのチェック
  - SSH公開鍵の形式検証

- **ip_validation_test.rb**: IPアドレス検証機能のテスト
  - 有効/無効なIPアドレスのテストケース
  - 正規化処理のテスト

### 統合テスト（`test/integration/`）

実際のさくらのクラウドAPIと連携するテスト。**本番環境では実行しないでください。**

- **test_with_packet_filter.rb**: 本番環境設定でのサーバー作成テスト
  - パケットフィルター（ファイアウォール）の適用確認
  - ポート22, 80, 443の開放確認

- **test_with_startup_script.rb**: スタートアップスクリプトのテスト
  - スクリプトID: 112900928939の実行確認
  - iptables設定、SSH強化設定の適用確認

- **test_server_with_notes.rb**: Notes APIフィールドのデバッグ
  - disk/config APIでのNotes設定動作確認
  - サーバー起動時のNotes指定確認

- **test_regex_patterns.rb**: Issue解析用正規表現のテスト
  - CoderDojo名の抽出パターン
  - IPアドレスの抽出パターン

## テストの実行方法

### ユニットテスト

```bash
# CSVフォーマットテスト
bundle exec ruby test/csv_test.rb

# IPアドレス検証テスト
bundle exec ruby test/ip_validation_test.rb

# すべてのユニットテスト
bundle exec rake test
```

### 統合テスト

⚠️ **警告**: これらのテストは実際のリソースを作成する可能性があります。

```bash
# 環境変数の設定が必要
export SACLOUD_ACCESS_TOKEN=xxxx
export SACLOUD_ACCESS_TOKEN_SECRET=xxxx
export SSH_PUBLIC_KEY_PATH=~/.ssh/id_rsa.pub

# 個別実行（テスト環境のみ）
ruby test/integration/test_with_packet_filter.rb test-server
ruby test/integration/test_with_startup_script.rb test-server
```

## 注意事項

1. **統合テストは本番環境で実行しない**
   - 実際のサーバーが作成される
   - 課金が発生する可能性がある

2. **API認証情報が必要**
   - `SACLOUD_ACCESS_TOKEN`
   - `SACLOUD_ACCESS_TOKEN_SECRET`

3. **SSH公開鍵が必要**
   - デフォルト: `~/.ssh/id_rsa.pub`
   - 環境変数: `SSH_PUBLIC_KEY_PATH`

## 関連ドキュメント

- [セキュリティ設計](../docs/security-defense-in-depth.md)
- [サーバー初期化手順](../docs/initialize-server.md)
- [SSH接続設定](../docs/ssh.md)