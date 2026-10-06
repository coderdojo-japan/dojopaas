require 'csv'
require 'date'
require_relative 'sakura_server_user_agent'

# servers.csv を読んで、ワークショップ用の指定（branch の隠しコマンド）を
# 申請者に伝えるメッセージを作る（PR の Checks のサマリーに出す）
#
# 申請者が知りたいのは次の2つだけ:
#   1. 隠しコマンドが読み取れたか
#   2. 読み取れたなら、いつ・どのスペックで作られるか
#
# 使い方:
#   WorkshopCheck.report(File.read('servers.csv'))  # => { status:, markdown: }
#   bundle exec rake workshop:check
module WorkshopCheck
  # 同じ PR に何度もコメントを足さないための目印
  MARKER = '<!-- dojopaas-workshop-check -->'.freeze

  PLAN         = SakuraServerUserAgent::WORKSHOP_PLAN
  PLAN_TEXT    = "#{PLAN[:CPU]}コア / #{PLAN[:MemoryMB] / 1024}GB".freeze
  DEFAULT      = SakuraServerUserAgent::DEFAULT_PLAN
  DEFAULT_TEXT = "#{DEFAULT[:CPU]}コア#{DEFAULT[:MemoryMB] / 1024}GB".freeze

  # 例示する日付を何日後にするか（申請は開催の1週間前が目安）
  EXAMPLE_DAYS_AHEAD = 7

  INSTANCES_URL = 'https://github.com/coderdojo-japan/dojopaas/blob/gh-pages/instances.csv'.freeze

  # @param csv_text [String] servers.csv の内容（fork 側の未検証データ）
  # @param today [Date] 例示する日付の基準。テストから固定値を渡す
  # @return [Hash] status: :ok / :problem / :none, markdown: コメント本文
  def self.report(csv_text, today: today_jst)
    candidates = workshop_candidates(csv_text)
    return { status: :none, markdown: '' } if candidates.empty?

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
  def self.workshop_candidates(csv_text)
    rows = begin
      CSV.parse(csv_text, headers: true)
    rescue CSV::MalformedCSVError
      return []
    end

    rows.each_with_index.filter_map do |row, index|
      branch = row['branch'].to_s.strip
      next unless SakuraServerUserAgent::WORKSHOP_BRANCH_LOOSE =~ branch

      { line: index + 2, name: row['name'].to_s.strip, branch: branch }
    end
  end

  def self.problems_in(row, today = today_jst)
    date = SakuraServerUserAgent.workshop_date(row[:branch])

    unless date
      return ["#{row[:line]}行目: `branch` が `#{row[:branch]}` になっています。" \
              '開催日を含めて `workshop-YYYYMMDD` の形で書いてください' \
              "（例: 1週間後なら `#{example_branch(today)}`）"]
    end

    problems = []
    begin
      Date.strptime(date, '%Y%m%d')
    rescue Date::Error
      problems << "#{row[:line]}行目: `#{date}` は存在しない日付です。開催日を確認してください"
    end

    unless row[:name].end_with?('-workshop')
      problems << "#{row[:line]}行目: `name` が `#{row[:name]}` になっています。" \
                  'ワークショップ用の行は `-workshop` で終わる名前にしてください' \
                  '（ふだんのサーバーと取り違えないためです）'
    end

    problems
  end

  def self.ok_report(rows)
    lines = []
    lines << '### ワークショップ用サーバーとして受け付けました'
    lines << ''
    lines << '| サーバー名 | 開催日 | スペック |'
    lines << '|---|---|---|'
    rows.each do |row|
      date = Date.strptime(SakuraServerUserAgent.workshop_date(row[:branch]), '%Y%m%d')
      lines << "| `#{row[:name]}` | #{date.strftime('%Y-%m-%d')} | #{PLAN_TEXT}（ふだんの#{PLAN[:CPU]}倍） |"
    end
    lines << ''
    lines << 'この PR が**マージされると、サーバーが作成されます**（ふだんの申請と同じ流れです）。'
    lines << "作成後、IP アドレスは[サーバー一覧](#{INSTANCES_URL})に載ります。"
    lines << '開催日のあとにサーバーを削除し、この行も削除します。'

    { status: :ok, markdown: lines.join("\n") }
  end
  private_class_method :ok_report

  def self.problem_report(problems, today = today_jst)
    lines = []
    lines << '### ワークショップ用の指定を読み取れませんでした'
    lines << ''
    problems.each { |p| lines << "- #{p}" }
    lines << ''
    lines << "このままマージすると、ふだんと同じ #{DEFAULT_TEXT} のサーバーが作られます。"
    lines << "`#{example_branch(today)}` のような形に直すと、Checks の表示も更新されます。"

    { status: :problem, markdown: lines.join("\n") }
  end
  private_class_method :problem_report
end
