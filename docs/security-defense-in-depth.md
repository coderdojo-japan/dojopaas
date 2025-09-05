# DojoPaaS セキュリティ設計：多層防御（Defense in Depth）

## 概要

DojoPaaSでは、CoderDojoのサーバーを保護するために**多層防御（Defense in Depth）**戦略を採用しています。これは、単一の防御機構に依存せず、複数の独立したセキュリティ層を重ねることで、より強固な防御を実現する設計思想です。

## 二層のファイアウォール構成

```
インターネット
    ↓
[Layer 1: さくらのクラウド パケットフィルター]
    ↓
サーバー
    ↓
[Layer 2: iptables (サーバー内部)]
    ↓
アプリケーション
```

### Layer 1: パケットフィルター（クラウド側）

**設定ID**: `112900922505`  
**管理場所**: さくらのクラウドコントロールパネル  
**特徴**: 
- サーバーの外側でトラフィックを制御
- サーバー起動前から有効
- 複数サーバーで設定を共有可能

**開放ポート**:
- 22/tcp (SSH)
- 80/tcp (HTTP)
- 443/tcp (HTTPS)
- 1024-65535/tcp (高位ポート)
- 1024-65535/udp (高位ポート)

### Layer 2: iptables（サーバー内部）

**設定ファイル**: `startup-scripts/112900928939`  
**管理場所**: サーバー内部（`/etc/iptables/rules.v4`）  
**特徴**:
- サーバー内部でトラフィックを制御
- より細かい制御が可能（rate limiting等）
- スタートアップスクリプトで自動設定

**セキュリティ機能**:
- SSH ブルートフォース攻撃対策（hashlimit）
- ICMP フラッド攻撃対策
- TCP フラグ異常パケットのドロップ
- IPv6 完全ブロック

## なぜ両方必要なのか？

### 1. 時系列での保護

```
サーバー起動
    ↓ [この間も保護が必要]
スタートアップスクリプト実行（数秒〜数分）
    ↓
iptables 有効化
```

パケットフィルターは**サーバー起動直後から有効**なため、スタートアップスクリプトが実行されるまでの間もサーバーを保護します。

### 2. 障害時の冗長性

- パケットフィルターが無効になっても → iptablesが保護
- iptables設定が失敗しても → パケットフィルターが保護
- どちらか片方が機能していれば、最低限のセキュリティを維持

### 3. 管理の観点

| 項目 | パケットフィルター | iptables |
|------|------------------|----------|
| 設定変更 | Webコンソール/API | SSH接続が必要 |
| 複数サーバー管理 | 一括設定可能 | 個別設定必要 |
| 設定の複雑さ | シンプル | 複雑な制御可能 |
| 適用タイミング | 即座 | 再起動/reload必要 |

### 4. 攻撃シナリオへの対策

**例：DDoS攻撃**
- Layer 1（パケットフィルター）: 基本的なフィルタリング
- Layer 2（iptables）: rate limitingで詳細な制御

**例：設定ミス**
- 管理者がiptablesを誤って無効化 → パケットフィルターが保護継続
- パケットフィルターの設定ミス → iptablesが最後の砦

## SSH セキュリティの追加強化

スタートアップスクリプトでは、ファイアウォールに加えてSSH自体のセキュリティも強化：

```bash
# rootログインを無効化
PermitRootLogin no

# パスワード認証を無効化（鍵認証のみ）
PasswordAuthentication no
```

## 実装コード

### パケットフィルターの適用（Ruby）

```ruby
# scripts/sakura_server_user_agent.rb
def apply_packet_filter(params = nil)
  @interface_id     ||= params[:interface_id]
  @packet_filter_id ||= params[:packet_filter_id]
  
  # パケットフィルターIDが指定されていない場合はスキップ
  if @packet_filter_id.nil?
    puts "パケットフィルターは適用されません（packet_filter_id is nil）"
    return
  end
  
  response = send_request('put', 
    "interface/#{@interface_id}/to/packetfilter/#{@packet_filter_id}", nil)
end
```

### デフォルト設定

```ruby
# デフォルトで本番環境のパケットフィルターを適用
def initialize(zone:"31002", packet_filter_id:'112900922505', ...)
  @packet_filter_id = packet_filter_id
  # ...
end
```

## テスト環境での無効化

開発・テスト環境では、必要に応じてパケットフィルターを無効化可能：

```ruby
# テスト用スクリプト
ssua = SakuraServerUserAgent.new(packet_filter_id: nil)
```

⚠️ **警告**: 本番環境では絶対にパケットフィルターを無効化しないでください。

## トラブルシューティング

### SSH接続できない場合

1. **パケットフィルター確認**
   ```bash
   ruby scripts/utils/check_packet_filter.rb
   ```

2. **サーバーステータス確認**
   ```bash
   ruby scripts/utils/check_server_status.rb <サーバー名>
   ```

3. **ポート疎通確認**
   ```bash
   curl -v telnet://<IPアドレス>:22 --max-time 3
   ```

### セキュリティ設定の確認

パケットフィルターの現在の設定を確認：
```bash
ruby scripts/utils/check_packet_filter.rb
```

期待される出力：
- ポート22, 80, 443が開放されている
- その他のポートは基本的にdeny

## ベストプラクティス

1. **両方の層を常に有効に保つ**
   - パケットフィルターとiptablesの両方を有効化
   - 片方だけに依存しない

2. **定期的な設定確認**
   - パケットフィルターIDが有効か確認
   - スタートアップスクリプトが最新か確認

3. **テスト環境での検証**
   - 本番環境に適用する前にテスト環境で検証
   - セキュリティ設定の変更は慎重に

4. **ログの監視**
   - 不正なアクセス試行を監視
   - 異常なトラフィックパターンを検知

## 関連ファイル

- `scripts/sakura_server_user_agent.rb` - パケットフィルター適用ロジック
- `startup-scripts/112900928939` - iptables設定スクリプト
- `scripts/utils/check_packet_filter.rb` - パケットフィルター確認ツール
- `scripts/utils/check_server_status.rb` - サーバー状態確認ツール

## 更新履歴

- 2019年9月: パケットフィルター機能を導入
- 2025年7月: cloud-init対応でSSH鍵設定を改善
- 2025年9月: 多層防御ドキュメント作成

---

*このドキュメントは、DojoPaaSのセキュリティ設計思想を説明するものです。実際の運用では、さくらインターネット様のセキュリティガイドラインも併せて参照してください。*