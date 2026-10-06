require 'minitest/autorun'
require 'date'
require_relative '../scripts/comment_workshop_check'

# fork から来た PR にも、判定結果をコメントで返す
# （初期化依頼の Issue が自動コメントで返しているのと同じ考え方）
class CommentWorkshopCheckTest < Minitest::Test
  HEADER = "name,branch,description,pubkey\n".freeze
  REGULAR = "coderdojo-naha,naha,CoderDojo那覇のサーバーです,ssh-ed25519 AAAA\n".freeze

  def test_no_comment_for_ordinary_pull_requests
    assert_nil CommentWorkshopCheck.body(HEADER + REGULAR),
               'ワークショップ用の行がない PR には何も書かない'
  end

  def test_comment_for_a_valid_row
    body = CommentWorkshopCheck.body(HEADER + "coderdojo-naha-workshop,workshop-20261115,那覇,ssh-ed25519 AAAA\n")

    assert_includes body, CommentWorkshopCheck::MARKER, '更新できるよう目印を入れる'
    assert_includes body, 'coderdojo-naha-workshop'
    assert_includes body, '2026-11-15'
    assert_includes body, '8コア'
  end

  def test_comment_for_a_broken_row
    body = CommentWorkshopCheck.body(HEADER + "coderdojo-naha-workshop,workshop,那覇,ssh-ed25519 AAAA\n",
                                     today: Date.new(2026, 10, 6))

    assert_includes body, CommentWorkshopCheck::MARKER
    assert_includes body, 'workshop-20261013', '1週間後の日付を例に出す'
    assert_includes body, '2行目'
  end

  def test_comment_for_a_broken_csv
    body = CommentWorkshopCheck.body(HEADER + %Q{coderdojo-naha-workshop,workshop-20261115,"閉じていない,ssh-ed25519 AAAA\n})

    assert_includes body, CommentWorkshopCheck::MARKER
    assert_includes body, 'CSV'
  end

  # 既にあるコメントを探して更新するための判定
  def test_finds_its_own_previous_comment
    comments = [
      { 'id' => 1, 'body' => 'ふつうのコメント' },
      { 'id' => 2, 'body' => "#{CommentWorkshopCheck::MARKER}\n前回の内容" },
    ]
    assert_equal 2, CommentWorkshopCheck.previous_comment_id(comments)
    assert_nil CommentWorkshopCheck.previous_comment_id([{ 'id' => 1, 'body' => 'x' }])
  end
end
