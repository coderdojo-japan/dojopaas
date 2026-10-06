require 'minitest/autorun'
require 'yaml'
require 'tempfile'

# GitHub Actions の run: に ${{ }} を書かないことを検証する
#
# ${{ }} はシェルが解釈する前に文字列として展開される。Issue 本文のように
# 誰でも書ける値を run: に展開すると、その内容がシェルスクリプトとして
# 実行されてしまう（コマンド注入）。値は env: 経由で渡す。
#
# https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#understanding-the-risk-of-script-injections
#
# なお actions/github-script の script: にも同じ性質があるが、そちらは
# 別途対応する（現状はマージ済みデータ由来の値のみを埋め込んでいる）。
class WorkflowSafetyTest < Minitest::Test
  WORKFLOW_DIR = File.expand_path('../.github/workflows', __dir__)

  def workflows
    Dir[File.join(WORKFLOW_DIR, '*.yml')].sort
  end

  def test_workflow_files_are_found
    refute_empty workflows, 'ワークフローが見つかりません（テストが空振りしていないかの確認）'
  end

  def test_no_template_expressions_in_run_blocks
    workflows.each do |path|
      each_step(path) do |job_name, index, step|
        run = step['run']
        next unless run.is_a?(String)

        # 式の中に } を含む書き方（${{ format('{0}', ...) }} など）も
        # 取りこぼさないよう、開始記号の有無だけで判定する
        refute_includes run, '${{',
                        "#{File.basename(path)} の #{job_name} step#{index} の run: に " \
                        '${{ }} が書かれています。env: 経由で渡してください' \
                        '（シェルに展開するとコマンド注入になります）'
      end
    end
  end

  # github-script の script: は JS として実行される。構文エラーがあっても
  # そのステップが走るまで分からない（「IP が見つからなかった時」のように
  # 失敗時しか通らないステップだと、PR の CI では一度も実行されない）
  #
  # 実際にテンプレートリテラルの中にエスケープしていないバッククォートを書いて
  # 壊したことがあるので、構文だけでも機械的に確かめる
  def test_github_script_blocks_are_valid_javascript
    skip 'node が無いため省略' if `which node`.strip.empty?

    checked = 0
    workflows.each do |path|
      each_step(path) do |job_name, index, step|
        next unless step['uses'].to_s.start_with?('actions/github-script')

        script = step.dig('with', 'script')
        next unless script.is_a?(String)

        checked += 1
        assert_valid_javascript script, "#{File.basename(path)} の #{job_name} step#{index}"
      end
    end

    # 固定値と比べると、ステップを増やしたときに数字の更新を忘れて取りこぼす。
    # ファイルに書かれている github-script の数と突き合わせる
    written = workflows.sum { |path| File.read(path).scan(/uses:\s*actions\/github-script/).size }
    assert_operator written, :>, 0, 'github-script のステップが見つかりません（テストが空振りしています）'
    assert_equal written, checked,
                 "github-script が #{written} 個あるのに #{checked} 個しか検査していません" \
                 '（script: が文字列でないステップは読み飛ばされます）'
  end

  private

  # ${{ }} は JS ではないので、構文チェックの前にダミーの文字列へ置き換える
  def assert_valid_javascript(script, where)
    source = script.gsub(/\$\{\{.*?\}\}/m, 'DUMMY')

    Tempfile.create(['github_script', '.js']) do |file|
      file.write(source)
      file.flush
      output = `node --check #{file.path} 2>&1`
      assert $?.success?, "#{where} の script: が JS として壊れています\n#{output}"
    end
  end

  def each_step(path)
    doc = YAML.load_file(path)
    (doc['jobs'] || {}).each do |job_name, job|
      (job['steps'] || []).each_with_index do |step, i|
        yield job_name, i + 1, step if step.is_a?(Hash)
      end
    end
  end
end
