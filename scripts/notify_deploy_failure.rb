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
  # 対応するのは保守者なので、確実に通知が届くようメンションする
  # （初期化依頼の自動応答と同じ流儀）
  MAINTAINER = ENV.fetch('DOJOPAAS_MAINTAINER', '@yasulab').freeze

  # マージコミットのメッセージから PR 番号を取り出す
  # このリポジトリはマージコミット運用なので、その形に固定する
  # （squash を使う日が来たら GitHub API で PR 番号を引く）
  # @return [String, nil] 数字のみ。見つからなければ nil
  def self.pr_number(message)
    message.to_s[/\AMerge pull request #(\d+)/, 1]
  end

  # @param run_url [String, nil] 実行ログの URL
  # @return [String] PR に投稿する本文
  def self.body(run_url: nil, missing: [])
    lines = []
    lines << '### サーバーの作成に失敗しました'
    lines << ''
    lines << 'マージは完了していますが、サーバーを作る処理の途中で止まりました。'
    lines << 'このままでは IP アドレスが一覧に出ません。'
    lines << ''
    unless missing.to_a.empty?
      lines << '作れていないサーバー:'
      missing.each { |name| lines << "- `#{name}`" }
      lines << ''
      lines << 'この PR とは別の行かもしれません。名前をご確認ください。'
      lines << ''
    end
    lines << "ログ: #{run_url}" if run_url && !run_url.empty?
    lines << ''
    lines << "#{MAINTAINER} CoderDojo Japan が内容を確認して対応します。"
    lines << 'お急ぎの場合や、しばらく動きがない場合は、この PR にコメントしてください。'
    lines.join("\n")
  end

  # gh コマンドでコメントする。失敗しても deploy の結果は変えない
  def self.post(message:, run_url:, missing: [])
    number = pr_number(message)
    if number.nil?
      warn 'PR 番号が見つからないため、通知しません'
      return false
    end

    require 'open3'
    _out, err, status = Open3.capture3('gh', 'pr', 'comment', number, '--body', body(run_url: run_url, missing: missing))
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
  # verify_created が書き出した名前を読む（同じ場所を参照する）
  require_relative 'verify_created'
  missing_file = VerifyCreated::MISSING_FILE
  missing = File.exist?(missing_file) ? File.read(missing_file).split("\n") : []

  DeployFailureNotice.post(message: message, run_url: run_url, missing: missing)
end
