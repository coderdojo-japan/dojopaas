# dojopaas

[![Build Status](https://travis-ci.org/coderdojo-japan/dojopaas.svg?branch=master)](https://travis-ci.org/coderdojo-japan/dojopaas)

このプロジェクトはさくらインターネット様からご提供いただいた「さくらのクラウド」上の各インスタンス及び、それぞれのサーバーアカウントを管理するためのプロジェクトです。

[servers.csv](https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv) に記載された情報に基づいてTravis CI経由で自動的にサーバーが起動します。

## サーバーがほしい方へ

以下のリンク先にあるCSVに対して必要事項を記入したプルリクエストをお願いします。

https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv

プルリクエストの例: https://github.com/coderdojo-japan/dojopaas/pull/1

### 各項目の説明

* name: サーバーの名前。他のものと重複しないようにしてください。FQDNとかがいいかもですね。これはインスタンスの名前に使用されます。
* branch: 道場の名前。アルファベットの小文字でお願いします。これはインスタンスのタグにも使用されます。
* description: サーバーの用途など、後からわかりやすいものをお願いします。
* pubkey: SSHで接続するための公開鍵。秘密鍵とまちがえないようくれぐれもお願いします。

公開鍵のサンプル: https://github.com/miya0001.keys

秘密鍵と公開鍵を絶対に間違えないようにお願いします。`git push`する前によーく確認してください。

### SSHの接続方法

以下のような感じで接続してください。

```
$ ssh ubuntu@<ip-address>
```

または

```
$ ssh -i <path-to-publickey> ubuntu@<ip-address>
```

* ユーザー名はすべて `ubuntu` です。
* プルリクエストの際にご連絡をいただいた公開鍵に対応する秘密鍵がないと接続できません。

プルリクエストがマージされて数分後に以下のURLにIPアドレスのリストがコミットされます。その中からご自身が申請したサーバーを探して、そのIPアドレスをSSHコマンドで指定してください。

https://github.com/coderdojo-japan/dojopaas/blob/gh-pages/instances.csv

## サーバーの仕様

* OS: Ubuntu 16.04
* CPU: 1コア
* メモリ: 1GB
* HDD: 20GB

## 管理者向けの情報

* リージョンは、石狩第二ゾーンです。
* 本システムで作成されたすべてのインスタンスには `dojopaas` というタグがついています。他の方法で起動したインスタンスにこのタグを付けないでください。
* CSVのフォーマットに対してもテストを行っています。赤いバツ印がある場合はエラーが出ているということなので、マージする前に原因を調べる必要があります。
