# SSH鍵の追加の仕方

このドキュメントは  
「CoderDojo Japanのさくらインターネットの提供しているサーバーを借りたものの、
他のメンターやニンジャに使わせたい」  
といった申請者さんのためのドキュメントです。

シェルコマンドを叩くこと、黒い画面に白い文字だけの画面の操作に抵抗のない人を想定しています。

コマンドサンプルの `<`, `>` で囲まれている箇所は、括弧ごと任意の文字列に書き換えてください。

## どんな時に出てくる作業？

サーバー申請者以外の人がサーバーを触る許可を与える際に出てきます。

## 手順

大まかな流れをコマンドで示します。

Mac, Linux, Windows Subsystem for Linux を想定しています。

### 繋げたい人

```shell
$ ssh-keygen -t rsa -b 4096 -C "dojopaas" # RSA暗号で4096バイト長の鍵をdojopaasというコメントをつけて生成。
Enter file in which to save the key (/Users/you/.ssh/id_rsa): # 「どこに鍵ファイルを保存します？」　と聞かれるので、鍵を保存するファイル名含むパスを記入
Enter passphrase (empty for no passphrase): # 「パスワードを入力して」と聞かれるので、鍵にさらにパスワードをつけたい場合は入力してEnter。なお、入力された内容は表示されないので注意。
Enter same passphrase again: # 「もう一度さっきのパスワード入力して」と聞かれるので入力。なお、入力された内容は表示されないので注意。

# 鍵ファイルが該当のパスに作成される。アスキーアートとかが出てくるが、念のため書き留めておいてもよい。
```

繋げたい人は、申請した人に`.pub`と最後に拡張子が付いたファイルを渡します。中身は文字列なのでそれをそのままコピー＆ペーストで送ってもいいです。

### 依頼された人（大体申請者）

すでにサーバーにログインしているものとします。

```shell
$ cd ~ # ホームディレクトリへ移動する
$ mkdir -p .ssh # ssh関係のディレクトリを作る。
$ touch .ssh/authorized_keys # 認証した人たちの情報（鍵の照合情報）を残すための空ファイルを作る。
$ chmod 700 .ssh # .sshディレクトリを、制作者だけが編集・実行でき、それ以外の者はできないようにする
$ chmod 600 .ssh/authorized_keys # .ssh_authorized_keysファイルを、制作者だけが編集のみできるようにする。
```

SSHの接続を一度切断し、以下を実行

```shell
$ cat <path/to/directory/pub_key.pub> | ssh ubuntu@<ip-address> 'cat >> .ssh/authorized_keys'
-- # 手元の<path/to/directory/key.pub>ファイルの中身をsshでつないだセッションに渡し、sshでつないだ先のサーバーの.ssh/authorized_keysに追記する。
```

### 接続確認（繋げたい人）

```shell
$ ssh -i <path/to/directory/key> ubuntu@<ip-address> # このコマンドでサーバーに接続する。
-- # 場合によってはここでパスワードを聞かれる。入力してEnter。打った文字列は表示されない。
```

## 参考資料

* [お前らのSSH Keysの作り方は間違っている - Qiita](https://qiita.com/suthio/items/2760e4cff0e185fe2db9)
* [ssh公開鍵認証設定まとめ - Qiita](https://qiita.com/ir-yk/items/af8550fea92b5c5f7fca)
