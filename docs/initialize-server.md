サーバーを初期化する方法
========================

READMEにあるフォームからサーバー初期化の依頼が来たときの対応方法をまとめています。

## 初期化の流れ

1. CoderDojo Japan の Slack グループ (#sakura) から `/sacloud list` を実行する
2. 表示されたリストの中から当該 Dojo のサーバー情報を見つける
3. (もしStatusが`up`であれば) `/sacloud halt <ID>` でサーバーを停止させる
4. `/sacloud destroy <ID>` で当該サーバーを削除する
5. [coderdojo-japan/dojopaas](https://github.com/coderdojo-japan/dojopaas/)リポジトリに空コミットをする
6. CIが動き、既存の [servers.csv](https://github.com/coderdojo-japan/dojopaas/blob/master/servers.csv) から当該サーバーが再生成 (初期化) されます
7. [instances.csv](https://github.com/coderdojo-japan/dojopaas/blob/gh-pages/instances.csv) を確認し、問題なければ当該 Issue を閉じてください

コードに手を加えていないため、この手順でCIが失敗することはないはずですが、もし失敗していた場合は CI の画面から Restart ボタンを押してみてください。

## 初期化の例

1. CoderDojo 岡山 岡南から[依頼が来る](https://github.com/coderdojo-japan/dojopaas/issues/77)
2. Slack の #sakura チャンネルで`/sacloud list` かを実行し、当該サーバー情報を見つける

> **coderdojo-konan-okayama**   
> **ID:** 112900984832   
> **IP Address:** 153.127.195.200   
> **Status:** up

3. Statusが `up` なので `/sacloud halt 112900984832` でサーバーを停止させる
4. `/sacloud destroy 112900984832` で当該サーバーを削除する
5. coderdojo-japan/dojopaas リポジトリに[空コミット](https://github.com/coderdojo-japan/dojopaas/commit/854418bb09e7d30ef5e62418f7f07da4855c3674)をする
6. [CIが無事に動作](https://travis-ci.org/coderdojo-japan/dojopaas/builds/315086462)すれば、削除したサーバーが再生成 (初期化) されます

> ...   
> Update startup scripts.   
> Archive ID:112901411351   
> Get a list of existing servers.   
> Create a server for coderdojo-konan-okayama.   
> Create a network interface.   
> Connect network interface.   
> Apply packet filter.   
> Create a disk.   
> Connect to the disk.   
> Setup ssh key.   
> ...   
> Copying image for coderdojo-konan-okayama...   
> Start server: 112901575095 for coderdojo-konan-okayama.   
> The `instances.csv` was saved!

7. [instances.csv](https://github.com/coderdojo-japan/dojopaas/commit/b74dba6a2e378dbfa36ea881729591fecca05fb5#diff-3dfe38357946121c2f0b04a2f80cec54R23) を確認し、CoderDojo 岡山 岡南のサーバーが生成されていることが確認できたので、[当該 Issue を閉じます](https://github.com/coderdojo-japan/dojopaas/issues/77)
