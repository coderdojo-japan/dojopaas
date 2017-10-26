文責: @manzyun
作成日: 2017-10-26
更新日: コミットログ参照

# ターミナコワクナイヨ -UNIX基本操作（移動編）-

この文章は、初めてdojopaasで作ったサーバーにアクセスした人のための、
基本的なコマンドの説明文章である。

主に初めてターミナルを触る人を想定して書いている。

かなりくだけた表現で書いているので、読んでいて、  
「馬鹿にされている気がする」  
と思った方は、ほかの文献を当ったほうがいいです。

## サーバー借りれたよ！

やった、ついにサーバーを借りれた！

とりあえず第一関門だったSSH接続は済んだぞ、だけど……

_「文字だけだ。マウスは文字選択しかできない。なにこれ？　てかつながってる？」_

と思ったことでしょう。

## オウム返しの挨拶

とりあえず、今あなたがSSHで接続しているウィンドウの内容はこんな感じだと思います。

```shell
ubuntu@nanika-yoku-wakaranai:~$
```

さっそく `$` の後ろに `echo Hello` と入力します。

```shell
ubuntu@nanika-yoku-wakaranai:~$ echo Hello
```

そして Enter キーを押します。

```shell
ubuntu@nanika-yoku-wakaranai:~$ echo Hello
Hello

ubuntu@nanika-yoku-wakaranai:~$
```

「**ひいっ！　しゃべった！**」

はい。しゃべります。

この `echo` というおまじないは、**コマンド**、つまり **命令** です。今何をしたかというと、  
「次に来る文字列をオウム返ししてね」  
という命令になります。

せっかくなので何回かオウム返ししてもらって交流しましょう。
次のウィンドウ内容サンプルを、何が返ってくるか期待しながら実行してみましょう。

```shell
ubuntu@nanika-yoku-wakaranai:~$ echo kowakunaiyo
ubuntu@nanika-yoku-wakaranai:~$ echo kuroigamen
ubuntu@nanika-yoku-wakaranai:~$ echo dont be afraid CUI
```

## やっと実用的なところ

### pwd 作業中の階層を表示

サーバーと対話できたことが確認できたので、次はサーバーの中を探検してみましょう。

とは書いたものの、ここはどこなのでしょうね。

```shell
ubuntu@nanika-yoku-wakaranai:~$ # 何も答えてくれない
```

そこで使うのが `pwd` コマンド。今作業中の階層を表示してくれるコマンドです。

```shell
ubuntu@nanika-yoku-wakaranai:~$ pwd
```

これでWebページのアドレスみたいな文字列が表示されます。つまりそこが今あなたの作業している階層です。

### ls | dir 階層にあるファイルを表示する。

「じゃあここの階層には何もないんだな！　なにやっても大丈夫だね！」

はい、すとーっぷ。次は `dir`　か `ls` というコマンドを実行してみましょう。

```shell
ubuntu@nanika-yoku-wakaranai:~$ ls # どっちでも
ubuntu@nanika-yoku-wakaranai:~$ dir # いいよ？
```

ずらずら文字列が表示されたと思います。これが今あなたの作業している階層にあるファイルと、別階層の入り口です。

さて、ここでちょっとトリック。 *オプション* を使ってみましょう。 `ls`　の後ろに一つ半角スペースを入れて `-a` と入力します。そしてEnter。

```shell
ubuntu@nanika-yoku-wakaranai:~$ ls -a
```

さっきよりも多くのファイルと別階層の入り口が表示されたと思います。

さて、その表示された文字列の中に、何か意味深な記号、 `./`, `../` があると思います。  
それぞれ、「今いる階層」と「一つ上の階層」の意味になります。

### cd 階層移動

それでは階層を移動してみましょう。

```shell
ubuntu@nanika-yoku-wakaranai:~$ cd ../
ubuntu@nanika-yoku-wakaranai:/home$ # おや？
```

気づきました？　さっきまでの `~` 文字が変わりましたね。

実はこの変わった部分を見て、今自分がどこにいるか確認できることが多いですが、
偶にそういう設定になっていないコンピューターもあります。だから `pwd` コマンドのこと、忘れないでね。

## おわりに

とりあえずサーバーの中をあちこち移動する基本的な方法はここまでで伝えたつもりです。

ですが、今まで紹介したコマンドも、オプションを使うことによって真の力を発揮します。

その真の力の見つけ方は…… `--help` オプションをつけて実行！

```shell
ubuntu@nanika-yoku-wakaranai:~$ ls --help
```

なに、説明書？　もちろんあるよ！

```shell
ubuntu@nanika-yoku-wakaranai:~$ man ls
```

分からないコマンドや忘れたコマンドがあったら、まず `--help` か `man`　読もうね。

## もっと詳しく

* [Dont Be Afraid Kuroigamen - FJORD,LLC(合同会社フィヨルド)](http://fjord.jp/tags/dont-be-afraid-kuroigamen/)
