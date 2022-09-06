# DojoPaaS ~ CoderDojo のためのサーバー利用申請手続き

[![Build Status](https://github.com/coderdojo-japan/dojopaas/actions/workflows/test.yml/badge.svg)](https://github.com/coderdojo-japan/dojopaas/actions/workflows/test.yml)

このプロジェクトはさくらインターネット様からご提供いただいた「さくらのクラウド」上の各インスタンス及び、それぞれのサーバーアカウントを管理するためのプロジェクトです。

[servers.csv](https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv) に記載された情報に基づいて[GitHub Actions](https://github.com/coderdojo-japan/dojopaas/actions)経由で自動的にサーバーが起動します。

## 📹 解説動画

サーバーを申請する準備から利用申請・削除までの手順を解説する動画を作りました! 「文章だけだと分かりにくい」といった場合にご活用ください ;)

[![DojoPaas 解説動画へのリンク](https://raw.githubusercontent.com/coderdojo-japan/dojopaas/master/img/youtube-thumbnail.png)](https://www.youtube.com/playlist?list=PL94GDfaSQTmIHQUGK2OKuXNk_QFs6_NTV)

下記の手順を説明する動画となっておりますので、GitHub や公開鍵認証などに慣れている場合は、下記の手順を読みながら直接進めていっても問題ありません 🆗 公開鍵認証がよくわからない場合は[「よく分かる公開鍵認証」～初心者でもよくわかる！VPSによるWebサーバー運用講座](https://knowledge.sakura.ad.jp/3543/)を読んでみてください 📑👀

## 1. サーバーがほしい方へ

以下のリンク先にあるCSVに対して必要事項を記入したプルリクエストをお願いします。

https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv   
プルリクエストの例: https://github.com/coderdojo-japan/dojopaas/pull/1

なお、代理での申請も受け付けております。その場合は代表から代理人に移譲された旨をプルリクエストにコメントしていただけると幸いです (参考: [代理申請の例](https://github.com/coderdojo-japan/dojopaas/pull/45))。

### 各項目の説明

* name: サーバーの名前。他のものと重複しないようにしてください。FQDNとかがいいかもですね。これはインスタンスの名前に使用されます。
* branch: 道場の名前。アルファベットの小文字でお願いします。これはインスタンスのタグにも使用されます。
* description: サーバーの用途など、後からわかりやすいものをお願いします。
* pubkey: SSHで接続するための公開鍵。秘密鍵とまちがえないようくれぐれもお願いします。

公開鍵のサンプル: https://github.com/miya0001.keys

**秘密鍵と公開鍵を間違えない** ようお願いします！ `git push`する前によーくご確認ください。

## 2. SSHの接続方法

プルリクエストがマージされてから１時間ほど経つと、以下のURLにIPアドレスのリストがコミットされます。その中からご自身が申請したサーバーを探して、そのIPアドレスをSSHコマンドで指定してください。

https://github.com/coderdojo-japan/dojopaas/blob/gh-pages/instances.csv

上記ファイル内に当該サーバーの行が追加されたら、次のような形式で接続できるようになります

```
$ ssh ubuntu@<ip-address>
```

または

```
$ ssh -i <path-to-privatekey> ubuntu@<ip-address>
```

* ユーザー名はすべて `ubuntu` です。
* プルリクエストの際にご連絡をいただいた公開鍵に対応する秘密鍵がないと接続できません。
* **ポート番号は22 (SSH), 80 (HTTP), 443 (HTTPS) のみが空いている状態になります。** 詳細は、サーバー生成時に実行される[スタートアップスクリプト](https://github.com/coderdojo-japan/dojopaas/blob/master/startup-scripts/112900928939)をご参照ください。

## 3. サーバーが不要になったとき

さくらインターネット様からご提供いただいているサーバーの台数には限りがあり、みなさんで共同利用するカタチとなっております。サーバー申請の流れと同じで、申請時に追加した行を [servers.csv](https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv) から削除することでサーバーの使用を停止できます。

- :octocat: [サーバー削除の申請例 (#213)](https://github.com/coderdojo-japan/dojopaas/pull/213)  

<!--
もし削除の手続きが分からない場合は、下記フォームから削除依頼を申請することもできます。もし削除の手続きが分からない場合はお気軽に下記フォームをご利用ください :relieved: :sparkling_heart:

- :postbox: [サーバー削除依頼の申請フォーム](https://github.com/coderdojo-japan/dojopaas/issues/new?title=サーバーの削除依頼&body=CoderDojo【道場名】の【申請者名】です。当該サーバー（IPアドレス：【xxx.xxx.xxx.xxx】）の削除をお願いします。cc/%20@yasulab&labels=サーバー削除依頼&assignee=yasulab)
-->


# よくある質問と回答

## Q. サーバーでどんなことができるの?
A. 例えばマインクラフト用のサーバーを立てることができます！[CoderDojo 三島・沼津](https://coderdojo-mn.com/)が用意したマイクラサーバー構築スクリプトがあるので、サーバーに詳しくない方でも手順に沿って進みやすくなっています。興味あればぜひ! :wink:

:octocat: [マインクラフトサーバー構築方法 (DojoPaaS利用者向け) - GitHub](https://github.com/urushibata/minecraft)
  

## Q. サーバーを初期化したい場合はどうすればよいですか?
A. [こちらのフォーム](https://github.com/coderdojo-japan/dojopaas/issues/new?title=サーバーの初期化依頼&body=CoderDojo【道場名】の【申請者名】です。当該サーバー（IPアドレス：【xxx.xxx.xxx.xxx】）の初期化をお願いします。cc/%20@yasulab%20@Yuppymam%20&labels=サーバー初期化依頼&assignee=yasulab)から依頼してもらえれば! 角カッコ `【】` に依頼する道場名、申請者名、IPアドレスをそれぞれ入力してください。 **( :warning: 初期化すると IP アドレスが変わるのでご注意ください)**

## Q. SSH で接続できなくなりました。どうすればよいですか?
A. CoderDojo Japan では各サーバーの管理までは対応しておりません。ただし、サーバーの初期化であれば対応できますので、必要であれば上記リンクから初期化依頼を出していただけると幸いです。

## Q. サーバーの知識があまりないです。どうすればよいですか?   
A. [@manzyun](https://github.com/manzyun) さんが書いてくれた[簡易ハンドブックがあります](https://github.com/coderdojo-japan/dojopaas/blob/master/docs/ssh.md)。基本的なポイントだけを押さえておりますので、必要に応じてご参照ください。

## Q. 作成されるサーバーの仕様を教えてください

* OS: Ubuntu 20.04
* CPU: 1コア
* メモリ: 1GB
* HDD: 20GB
* リージョン: 石狩第二ゾーン
  
## Q. `ooo.coderdojo.jp` のようなサブドメインは使えますか?
A. 以前、実験的にサブドメインを各 Dojo に提供した期間がありましたが、DNSの更新・管理のコストが肥大化し他の業務に支障が出てしまったため、現在は [DecaDojo](https://decadojo.coderdojo.jp/) や [DojoCon Japan](https://dojocon2020.coderdojo.jp/) などのケースを除いて、サブドメインの提供には対応しておりません。なお、更新・管理コストの肥大化が原因であるため、DojoPaaS のような自動化が DNS でも実現できれば、受付を再開できる可能性があります。

## Q. 開発に貢献する方法を教えてください

ローカルでテストするには以下の要領でお願いします。

### 環境変数を設定

さくらのクラウドのAPIへの接続に必要な情報を環境変数で設定してください。

```
export SACLOUD_ACCESS_TOKEN=xxxx
export SACLOUD_ACCESS_TOKEN_SECRET=xxxx
```

### 実行

```
$ gem install
$ bundle exec rake test # 単体のテスト
$ bundle exec ruby ruby_scripts/deploy.rb # 本番環境でインスタンスを作成
```

<!--
```
$ npm install
$ npm test # 単体のテスト
$ npm run test:csv # CSVに対するテスト
$ npm run deploy # サンドボックスにインスタンスを作成
$ npm run deploy -- --production # 本番環境でインスタンスを作成
```
-->

### 開発時の注意事項

* 本システムで作成されたすべてのインスタンスには `dojopaas` というタグをつけ、そのタグを利用しています。他の方法で起動したインスタンスにこのタグを付けないでください
* CSVのフォーマットに対してもテストを行っています。CI の結果に赤いバツ印がある場合はエラーが出ているということなので、マージする前に原因を調べていただけると幸いです


## DojoPaaS 関連記事

- [さくらインターネット、子ども向けプログラミング道場「CoderDojo」にサーバー100台を追加支援 〜さくらのクラウド計200台を無料提供〜](https://www.sakura.ad.jp/information/pressreleases/2020/03/25/1968203191/)
- [子ども向けプログラミング道場を推進する一般社団法人 CoderDojo Japan をさくらインターネットが支援、「さくらのクラウド」を無料提供](https://www.sakura.ad.jp/press/2017/0720_cloud-coderjapan/)
- [CoderDojo を楽しむ 〜 DojoPaaS (さくらのオフライン通信)](https://github.com/coderdojo-japan/dojopaas/issues/51#issuecomment-326204848)
- [さくらインターネット株式会社様より、全国の #CoderDojo を対象としたサーバー環境 (計100台分) のご支援をしていただくことになりました!](https://www.facebook.com/coderdojo.jp/posts/673793186165170)
- [さくらのクラウドとGitHub+Travis CIを使ってCoderDojo向けのプルリクドリブンのPaaSサービスを3日で作った！](https://tarosky.co.jp/tarog/2086)
  - :memo: 2021年6月より、Travis CI から GitHub Actions に移行されました 🚜💨

# 開発・運営

- 共同発起人: [@miya0001](https://github.com/miya0001)
- 共同発起人: [@yasulab](https://github.com/yasulab)
- 開発・運営: [YassLab 株式会社](https://yasslab.jp/ja/)

Copyright &copy; 一般社団法人 CoderDojo Japan   
https://coderdojo.jp/
