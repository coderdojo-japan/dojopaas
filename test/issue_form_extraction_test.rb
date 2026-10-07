require 'minitest/autorun'
require_relative '../scripts/initialize_server'

# Issue フォーム（.github/ISSUE_TEMPLATE/initialize_server.yml）で作られた本文から
# 道場名と IP アドレスを取り出す
#
# フォームの本文は「### ラベル」+ 空行 + 値 に整形される。見出しの直下だけを見るので、
# コメント欄に別の IP が書かれていても拾わない（旧形式の自由記述は取り違えうる）
class IssueFormExtractionTest < Minitest::Test
  FORM_BODY = <<~BODY
    ### 道場名

    那覇

    ### 道場代表者の氏名

    安川要平

    ### IPアドレス

    133.242.224.96

    ### コメント欄（任意）

    _No response_
  BODY

  def test_dojo_name_from_form
    assert_equal '那覇', ServerInitializer.extract_dojo_name(FORM_BODY)
  end

  def test_ip_address_from_form
    assert_equal '133.242.224.96', ServerInitializer.extract_ip_address(FORM_BODY)
  end

  # コメント欄は読まない。ここに書かれた IP を拾うと、別のサーバーを削除しうる
  def test_ip_in_comment_section_is_ignored
    body = FORM_BODY.sub('_No response_', '前のサーバー（133.242.1.1）とは別です')
    assert_equal '133.242.224.96', ServerInitializer.extract_ip_address(body)
  end

  def test_dojo_name_is_not_taken_from_comment_section
    body = FORM_BODY.sub('_No response_', 'CoderDojo 名護 の事例を参考にしました')
    assert_equal '那覇', ServerInitializer.extract_dojo_name(body)
  end

  # 既存の Issue（自由記述テンプレート）も読めること
  OLD_BODY = 'CoderDojo【那覇】の【安川要平】です。' \
             '当該サーバー（IPアドレス：【133.242.224.96】）の初期化をお願いします。'

  def test_old_free_text_body_still_works
    assert_equal '那覇',           ServerInitializer.extract_dojo_name(OLD_BODY)
    assert_equal '133.242.224.96', ServerInitializer.extract_ip_address(OLD_BODY)
  end

  def test_blank_body_returns_nil
    assert_nil ServerInitializer.extract_dojo_name('')
    assert_nil ServerInitializer.extract_ip_address(nil)
  end

  # 未入力のまま送信された場合（required なので起きないが、API 経由では起きうる）
  def test_no_response_placeholder_is_not_a_value
    body = "### 道場名\n\n_No response_\n\n### IPアドレス\n\n_No response_\n"
    assert_nil ServerInitializer.extract_dojo_name(body)
    assert_nil ServerInitializer.extract_ip_address(body)
  end
end

# 見出しがあるのに値が無い場合は、旧パターンのフォールバックに降りない
#
# フォームで送られた以上、値は見出しの下にしか無い。本文の他の場所を探すと、
# コメント欄に書かれた IP を拾ってしまう（UI では required で防げるが、API 経由では起きうる）
class IssueFormEmptyFieldTest < Minitest::Test
  def body_with(ip_value:, dojo_value:, comment:)
    <<~BODY
      ### 道場名

      #{dojo_value}

      ### IPアドレス

      #{ip_value}

      ### コメント欄（任意）

      #{comment}
    BODY
  end

  def test_empty_ip_field_does_not_fall_back_to_the_comment
    body = body_with(ip_value: '_No response_', dojo_value: '那覇',
                     comment: 'IPアドレス：133.242.1.1 のサーバーです')
    assert_nil ServerInitializer.extract_ip_address(body)
  end

  def test_empty_dojo_field_does_not_fall_back_to_the_comment
    body = body_with(ip_value: '133.242.224.96', dojo_value: '_No response_',
                     comment: 'CoderDojo【名護】の例を見ました')
    assert_nil ServerInitializer.extract_dojo_name(body)
  end

  # 見出しそのものが無い（旧テンプレート）時だけフォールバックする
  def test_old_format_still_falls_back
    old = 'CoderDojo【那覇】です。当該サーバー（IPアドレス：【133.242.224.96】）の初期化をお願いします。'
    assert_equal '那覇',           ServerInitializer.extract_dojo_name(old)
    assert_equal '133.242.224.96', ServerInitializer.extract_ip_address(old)
  end
end
