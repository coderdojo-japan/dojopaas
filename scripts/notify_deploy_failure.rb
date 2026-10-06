# マージ後にサーバーの作成が失敗したことを、PR を出した人に伝える
#
# マージ前の失敗は Checks と該当行の注釈で見えるが、マージ後の失敗は
# 誰にも届かない。申請者は、来ない IP を待ち続けることになる。
#
# main への push で動くジョブから実行する。fork のコードは一切実行しないため、
# pull_request_target のような強い権限は要らない。
#
# 使い方: bundle exec ruby scripts/notify_deploy_failure.rb
module DeployFailureNotice
  # マージコミットのメッセージから PR 番号を取り出す
  # "Merge pull request #280 from ..." / "feat: ... (#281)" のどちらにも対応する
  # @return [String, nil] 数字のみ。見つからなければ nil
  def self.pr_number(message)
    message.to_s[/#(\d+)/, 1]
  end

  # @param run_url [String, nil] 実行ログの URL
  # @return [String] PR に投稿する本文
  def self.body(run_url: nil)
    lines = []
    lines << '### サーバーの作成に失敗しました'
    lines << ''
    lines << 'マージは完了していますが、サーバーを作る処理の途中で止まりました。'
    lines << 'このままでは IP アドレスが一覧に出ません。'
    lines << ''
    lines << "ログ: #{run_url}" if run_url && !run_url.empty?
    lines << ''
    lines << 'CoderDojo Japan が内容を確認して対応します。'
    lines << 'お急ぎの場合や、しばらく動きがない場合は、この PR にコメントしてください。'
    lines.join("\n")
  end

  # gh コマンドでコメントする。失敗しても deploy の結果は変えない
  def self.post(message:, run_url:)
    number = pr_number(message)
    if number.nil?
      warn 'PR 番号が見つからないため、通知しません'
      return false
    end

    require 'open3'
    _out, err, status = Open3.capture3('gh', 'pr', 'comment', number, '--body', body(run_url: run_url))
    if status.success?
      puts "PR ##{number} に失敗を通知しました"
      true
    else
      warn "通知に失敗しました: #{err.strip}"
      false
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  message = `git log -1 --pretty=%B`
  run_url = if ENV['GITHUB_SERVER_URL'] && ENV['GITHUB_REPOSITORY'] && ENV['GITHUB_RUN_ID']
              "#{ENV['GITHUB_SERVER_URL']}/#{ENV['GITHUB_REPOSITORY']}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
            end
  DeployFailureNotice.post(message: message, run_url: run_url)
end
