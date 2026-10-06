require 'json'
require 'open3'
require_relative 'workshop_check'

# ワークショップ用の行がある PR に、判定結果をコメントで返す
#
# 初期化依頼の Issue が自動コメントで返しているのと同じ考え方を、PR にも広げる。
# fork から来た PR にコメントするには base 側の文脈で動く必要があるため、
# pull_request_target で起動する。
#
# 安全のための約束（ワークフロー側と対で守る）:
#   - fork のコードは一切チェックアウトも実行もしない
#   - 読むのは PR の servers.csv の中身（テキスト）だけ
#   - 判定するコードは base ブランチのもの
#   - このジョブに本番の秘密情報は渡さない
#
# 使い方: PR_NUMBER=123 bundle exec ruby scripts/comment_workshop_check.rb <csvのパス>
module CommentWorkshopCheck
  # 同じ PR にコメントを足し続けず、前回のものを書き換えるための目印
  MARKER = '<!-- dojopaas-workshop-check -->'.freeze

  # @return [String, nil] 投稿する本文。言うことがなければ nil
  def self.body(csv_text, today: WorkshopCheck.today_jst)
    result = WorkshopCheck.report(csv_text, today: today)
    return nil if result[:status] == :none

    [MARKER, result[:markdown]].join("\n")
  end

  # @param comments [Array<Hash>] GitHub API が返すコメントの配列
  # @return [Integer, nil] 自分が前に書いたコメントの id
  def self.previous_comment_id(comments)
    found = comments.find { |c| c['body'].to_s.include?(MARKER) }
    found && found['id']
  end

  def self.gh(*args, input: nil)
    out, err, status = Open3.capture3('gh', *args, stdin_data: input.to_s)
    raise "gh #{args.first} に失敗しました: #{err.strip}" unless status.success?

    out
  end

  def self.post(pr_number:, body:, repo: ENV['GITHUB_REPOSITORY'])
    comments = JSON.parse(gh('api', "repos/#{repo}/issues/#{pr_number}/comments", '--paginate'))
    id = previous_comment_id(comments)

    if id
      gh('api', '--method', 'PATCH', "repos/#{repo}/issues/comments/#{id}",
         '-f', "body=#{body}")
      puts "PR ##{pr_number} のコメントを更新しました"
    else
      gh('api', '--method', 'POST', "repos/#{repo}/issues/#{pr_number}/comments",
         '-f', "body=#{body}")
      puts "PR ##{pr_number} にコメントしました"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  path = ARGV[0] || 'servers.csv'
  pr   = ENV['PR_NUMBER']
  abort 'PR_NUMBER が指定されていません' if pr.to_s.strip.empty?

  text = File.read(path)
  body = CommentWorkshopCheck.body(text)

  if body.nil?
    puts 'ワークショップ用の行はないので、コメントしません'
  else
    CommentWorkshopCheck.post(pr_number: pr, body: body)
  end
end
