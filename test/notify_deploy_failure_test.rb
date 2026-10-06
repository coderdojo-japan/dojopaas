require 'minitest/autorun'
require_relative '../scripts/notify_deploy_failure'

# マージ後にサーバー作成が失敗したとき、PR を出した人に伝える
#
# マージ前の失敗は Checks と該当行の注釈で見えるが、マージ後の失敗は
# 誰にも届かない。申請者は来ない IP を待ち続けることになる
class NotifyDeployFailureTest < Minitest::Test
  def test_extracts_pr_number_from_merge_commit
    message = "Merge pull request #280 from coderdojo-japan/demo-workshop-success\n\ndemo: ..."
    assert_equal '280', DeployFailureNotice.pr_number(message)
  end

  # このリポジトリはマージコミット運用なので、その形だけを認める
  # 本文中の #番号 を拾うと、関係ない Issue 番号に通知しかねない
  def test_ignores_numbers_that_are_not_a_merge_commit
    assert_nil DeployFailureNotice.pr_number("feat: ワークショップ用サーバー (#281)")
    assert_nil DeployFailureNotice.pr_number("Fix #269: Initialize server")
  end

  def test_returns_nil_without_a_pr_number
    assert_nil DeployFailureNotice.pr_number("Fix typo")
    assert_nil DeployFailureNotice.pr_number("")
    assert_nil DeployFailureNotice.pr_number(nil)
  end

  # 番号らしきものが複数あるときは、最初のものを使う（マージコミットの形）
  def test_uses_the_first_number
    assert_equal '270', DeployFailureNotice.pr_number("Merge pull request #270 from x (closes #269)")
  end

  def test_body_tells_what_happened_and_what_is_next
    body = DeployFailureNotice.body(run_url: 'https://github.com/x/y/actions/runs/1')

    assert_includes body, 'サーバーの作成に失敗', '何が起きたかを書く'
    assert_includes body, 'https://github.com/x/y/actions/runs/1', 'ログへのリンクを載せる'
    assert_includes body, 'CoderDojo Japan', '誰が対応するかを書く'
    refute_includes body, 'SACLOUD', '秘密情報の名前は出さない'
  end

  # 本文に名前が無いと、別の PR の作者が「自分の申請が失敗した」と誤解する
  def test_body_names_the_missing_servers
    body = DeployFailureNotice.body(run_url: nil, missing: %w[coderdojo-naha-workshop])

    assert_includes body, 'coderdojo-naha-workshop'
    assert_includes body, 'この PR とは別の行', '他の行の失敗かもしれないと伝える'
  end

  # 対応するのは保守者なので、確実に通知が届くようメンションする
  # （初期化依頼の自動応答と同じ流儀）
  def test_body_mentions_the_maintainer
    assert_includes DeployFailureNotice.body(run_url: nil), DeployFailureNotice::MAINTAINER
  end

  def test_body_works_without_a_run_url
    body = DeployFailureNotice.body(run_url: nil)
    assert_includes body, 'サーバーの作成に失敗'
  end
end
