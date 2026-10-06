require 'minitest/autorun'
require_relative '../scripts/workshop_check'

# PR に返すメッセージを作る部分のテスト
# 申請者が「隠しコマンドが効いたか」をその場で分かるようにする
class WorkshopCheckTest < Minitest::Test
  HEADER = "name,branch,description,pubkey\n".freeze
  REGULAR_ROW = "coderdojo-naha,naha,CoderDojo那覇のサーバーです,ssh-ed25519 AAAA\n".freeze

  def report(*rows)
    WorkshopCheck.report(HEADER + rows.join)
  end

  # CSV の値は fork 側が自由に書ける。Markdown にそのまま埋めると、
  # bot 名義のコメントに任意のリンクやメンションを仕込めてしまう
  def test_values_cannot_break_out_of_the_markdown
    row = "coderdojo-x-workshop,workshop-20261115,説明,ssh-ed25519 AAAA\n"
            .sub("coderdojo-x-workshop", "coderdojo-`](http://example.com)-workshop")
    body = WorkshopCheck.report(HEADER + row)[:markdown]

    refute_includes body, "](http://example.com)", "リンクの形を持ち込ませない"
    refute_includes body, "`](", "コードスパンから抜け出させない"
  end

  def test_mentions_are_defused
    row = "coderdojo-x-workshop,workshop,@yasulab を呼ぶ説明,ssh-ed25519 AAAA\n"
            .sub("coderdojo-x-workshop", "@yasulab-workshop")
    body = WorkshopCheck.report(HEADER + row)[:markdown]

    refute_includes body, "@yasulab", "メンションをそのまま出さない"
  end

  def test_no_workshop_row_reports_nothing_to_say
    result = report(REGULAR_ROW)
    assert_equal :none, result[:status], "ふだんの申請では何も言わない（コメントしない）"
  end

  def test_valid_workshop_row_is_recognized
    result = report(REGULAR_ROW, "coderdojo-naha-workshop,workshop-20261115,那覇ワークショップ用,ssh-ed25519 AAAA\n")
    assert_equal :ok, result[:status]
    assert_includes result[:markdown], "coderdojo-naha-workshop"
    assert_includes result[:markdown], "2026-11-15", "開催日は読みやすい形で出す"
    assert_includes result[:markdown], "8コア", "作られるスペックを明記する"
    assert_includes result[:markdown], "マージ", "マージで作成されることを伝える"
  end

  # 成功時も PR の該当行に出す（Checks を開かなくても分かるように）
  def test_valid_row_returns_a_notice_for_the_line
    result = report(REGULAR_ROW, "coderdojo-naha-workshop,workshop-20261115,那覇ワークショップ用,ssh-ed25519 AAAA\n")

    assert_equal :ok, result[:status]
    notice = result[:notices].first
    refute_nil notice, "成功時にも行ごとの注記を返す"
    assert_equal 3, notice[:line], "ヘッダーを含めた行番号"
    assert_includes notice[:message], "coderdojo-naha-workshop"
    assert_includes notice[:message], "2026-11-15"
    assert_includes notice[:message], "8コア"
  end

  def test_problem_report_has_no_notices
    result = report("coderdojo-naha-workshop,workshop,那覇,ssh-ed25519 AAAA\n")
    assert_empty result[:notices]
  end

  def test_branch_without_date_is_reported_as_a_problem
    result = report("coderdojo-naha-workshop,workshop,那覇ワークショップ用,ssh-ed25519 AAAA\n")
    assert_equal :problem, result[:status]
    assert_includes result[:markdown], "workshop-YYYYMMDD"
  end

  def test_impossible_date_is_reported_as_a_problem
    result = report("coderdojo-naha-workshop,workshop-20261332,那覇ワークショップ用,ssh-ed25519 AAAA\n")
    assert_equal :problem, result[:status]
    assert_includes result[:markdown], "20261332"
  end

  def test_name_must_end_with_workshop
    result = report("coderdojo-naha,workshop-20261115,那覇ワークショップ用,ssh-ed25519 AAAA\n")
    assert_equal :problem, result[:status]
    assert_includes result[:markdown], "-workshop"
  end

  def test_multiple_workshop_rows_are_all_listed
    result = report(
      "coderdojo-naha-workshop,workshop-20261115,那覇,ssh-ed25519 AAAA\n",
      "coderdojo-ome-workshop,workshop-20261220,青梅,ssh-ed25519 AAAA\n"
    )
    assert_equal :ok, result[:status]
    assert_includes result[:markdown], "coderdojo-naha-workshop"
    assert_includes result[:markdown], "coderdojo-ome-workshop"
  end

  # CSV は fork 側の未検証データなので、壊れていても落ちないこと
  def test_broken_csv_does_not_raise
    result = WorkshopCheck.report("これは CSV ではありません\"\"\"")
    assert_equal :broken, result[:status]
  end

  # 壊れた CSV を「ワークショップ用の行はありません」と報告してはいけない
  # （行はあるのに読めなかっただけで、PR 作成者が原因を取り違える）
  def test_unclosed_quote_is_reported_as_broken_csv
    broken = HEADER + %Q{coderdojo-naha-workshop,workshop-20261115,"説明が閉じていない,ssh-ed25519 AAAA\n}
    result = WorkshopCheck.report(broken)

    assert_equal :broken, result[:status]
    assert_includes result[:markdown], "CSV", "CSV として読めないことを伝える"
    assert_includes result[:markdown], "2行目", "何行目かを伝える"
    refute_includes result[:markdown], "ワークショップ用の行はありません"
  end
end

# 例示する日付が「今日から1週間後」になることの検証
# 日付に依存するので、基準日はテストから固定して渡す
class WorkshopCheckExampleDateTest < Minitest::Test
  HEADER = "name,branch,description,pubkey\n".freeze

  def test_example_shows_a_date_one_week_ahead
    result = WorkshopCheck.report(
      HEADER + "coderdojo-naha-workshop,workshop,那覇,ssh-ed25519 AAAA\n",
      today: Date.new(2026, 10, 6)
    )
    assert_includes result[:markdown], 'workshop-20261013', '1週間後の日付を例に出す'
    refute_includes result[:markdown], 'workshop-20261115', '固定の例は使わない'
  end

  def test_example_crosses_month_boundaries
    result = WorkshopCheck.report(
      HEADER + "coderdojo-naha-workshop,workshop,那覇,ssh-ed25519 AAAA\n",
      today: Date.new(2026, 12, 28)
    )
    assert_includes result[:markdown], 'workshop-20270104', '年をまたいでも正しく出す'
  end

  def test_today_jst_is_used_by_default
    assert_equal Time.now.getlocal('+09:00').to_date, WorkshopCheck.today_jst
  end
end
