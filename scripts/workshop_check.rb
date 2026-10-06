require 'csv'
require 'date'
require_relative 'sakura_server_user_agent'

# servers.csv を読んで、ワークショップ用の指定（branch の隠しコマンド）を
# PR を出した人に伝えるメッセージを作る（PR の Checks のサマリーに出す）
#
# 知りたいのは次の2つだけ:
#   1. 隠しコマンドが読み取れたか
#   2. 読み取れたなら、いつ・どのスペックで作られるか
#
# 使い方:
#   WorkshopCheck.report(File.read('servers.csv'))  # => { status:, markdown:, problems: }
#   bundle exec rake workshop:check
module WorkshopCheck
  PLAN         = SakuraServerUserAgent::WORKSHOP_PLAN
  PLAN_TEXT    = "#{PLAN[:CPU]}コア / #{PLAN[:MemoryMB] / 1024}GB".freeze
  DEFAULT      = SakuraServerUserAgent::DEFAULT_PLAN
  DEFAULT_TEXT = "#{DEFAULT[:CPU]}コア#{DEFAULT[:MemoryMB] / 1024}GB".freeze

  # 例示する日付を何日後にするか（開催の1週間前が目安）
  EXAMPLE_DAYS_AHEAD = 7

  INSTANCES_URL = 'https://github.com/coderdojo-japan/dojopaas/blob/gh-pages/instances.csv'.freeze

  # @param csv_text [String] servers.csv の内容（fork 側の未検証データ）
  # @param today [Date] 例示する日付の基準。テストから固定値を渡す
  # @return [Hash] status: :ok / :problem / :broken / :none
  #                markdown: Checks に出す本文
  #                problems: [{line:, message:}] アノテーション用
  def self.report(csv_text, today: today_jst)
    rows = begin
      CSV.parse(csv_text, headers: true)
    rescue CSV::MalformedCSVError => e
      return broken_report(e)
    end

    candidates = workshop_candidates(rows)
    return { status: :none, markdown: '', problems: [] } if candidates.empty?

    problems = candidates.flat_map { |row| problems_in(row, today) }
    problems.empty? ? ok_report(candidates) : problem_report(problems, today)
  end

  # 日付の判断は JST で行う（CI は UTC で動く）
  def self.today_jst
    Time.now.getlocal('+09:00').to_date
  end

  # 書き方の例。1週間後の日付を出して「いつを書くか」を想像しやすくする
  def self.example_branch(today)
    'workshop-' + (today + EXAMPLE_DAYS_AHEAD).strftime('%Y%m%d')
  end

  # branch に workshop を含む行だけを拾う（惜しい書き方も拾って指摘するため）
  def self.workshop_candidates(rows)
    rows.each_with_index.filter_map do |row, index|
      branch = row['branch'].to_s.strip
      next unless SakuraServerUserAgent::WORKSHOP_BRANCH_LOOSE =~ branch

      { line: index + 2, name: row['name'].to_s.strip, branch: branch }
    end
  end

  def self.problems_in(row, today = today_jst)
    date = SakuraServerUserAgent.workshop_date(row[:branch])

    unless date
      return [{ line: row[:line],
                message: "`branch` が `#{row[:branch]}` になっています。" \
                         '開催日を含めて `workshop-YYYYMMDD` の形で書いてください' \
                         "（例: 1週間後なら `#{example_branch(today)}`）" }]
    end

    problems = []
    begin
      Date.strptime(date, '%Y%m%d')
    rescue Date::Error
      problems << { line: row[:line],
                    message: "`#{date}` は存在しない日付です。開催日を確認してください" }
    end

    unless row[:name].end_with?('-workshop')
      problems << { line: row[:line],
                    message: "`name` が `#{row[:name]}` になっています。" \
                             'ワークショップ用の行は `-workshop` で終わる名前にしてください' \
                             '（ふだんのサーバーと取り違えないためです）' }
    end

    problems
  end

  def self.ok_report(rows)
    lines = ['### ワークショップ用サーバーとして受け付けました', '',
             '| サーバー名 | 開催日 | スペック |', '|---|---|---|']
    rows.each do |row|
      date = Date.strptime(SakuraServerUserAgent.workshop_date(row[:branch]), '%Y%m%d')
      lines << "| `#{row[:name]}` | #{date.strftime('%Y-%m-%d')} | #{PLAN_TEXT}（ふだんの#{PLAN[:CPU]}倍） |"
    end
    lines += ['', 'この PR が**マージされると、サーバーが作成されます**（ふだんの流れと同じです）。',
              "作成後、IP アドレスは[サーバー一覧](#{INSTANCES_URL})に載ります。",
              '開催日のあとにサーバーを削除し、この行も削除します。']

    { status: :ok, markdown: lines.join("\n"), problems: [] }
  end
  private_class_method :ok_report

  def self.problem_report(problems, today = today_jst)
    lines = ['### ワークショップ用の指定を読み取れませんでした', '']
    problems.each { |p| lines << "- #{p[:line]}行目: #{p[:message]}" }
    lines += ['', "このままマージすると、ふだんと同じ #{DEFAULT_TEXT} のサーバーが作られます。",
              "`#{example_branch(today)}` のような形に直すと、Checks の表示も更新されます。"]

    { status: :problem, markdown: lines.join("\n"), problems: problems }
  end
  private_class_method :problem_report

  # 行番号は CSV のレコード番号。引用符内に改行を含むセルがあると物理行とずれる
  # （servers.csv に複数行セルは無いため、現状は一致する）
  # CSV として読めないときは、黙って「行はありません」と言わない
  # （行はあるのに読めなかっただけで、原因を取り違えるため）
  def self.broken_report(error)
    line = error.line_number if error.respond_to?(:line_number)
    where = line ? "#{line}行目あたり" : '場所は不明'
    message = "servers.csv を CSV として読めませんでした（#{where}）。" \
              '引用符やカンマの対応を確認してください'

    { status: :broken,
      markdown: ['### servers.csv を読めませんでした', '', "- #{message}", '',
                 '1行は `name,branch,description,pubkey` の4項目です。' \
                 '説明に読点やカンマを含める場合は、全体を引用符で囲んで閉じてください。'].join("\n"),
      problems: [{ line: line || 1, message: message }] }
  end
  private_class_method :broken_report
end
