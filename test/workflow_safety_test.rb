require 'minitest/autorun'
require 'yaml'
require 'tempfile'
require 'open3'

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

  # actions/github-script の script: も同じ性質を持つ。
  # ${{ }} は JS が読まれる前に文字列として埋め込まれるので、値にバッククォートや
  # ${ が含まれると構文エラーになり、そのステップは何もしないまま終わる。
  # 値は env: で渡して process.env から読む。
  #
  # 安全そうな値（IP など）だけ例外にすると、判定が人手に戻って見落としが再発する。
  # script: には一切書かない、で統一する。
  def test_no_template_expressions_in_github_script_blocks
    checked = 0
    workflows.each do |path|
      each_step(path) do |job_name, index, step|
        next unless step['uses'].to_s.start_with?('actions/github-script')

        script = step.dig('with', 'script')
        next unless script.is_a?(String)

        checked += 1
        refute_includes script, '${{',
                        "#{File.basename(path)} の #{job_name} step#{index} の script: に " \
                        '${{ }} が書かれています。env: 経由で渡して process.env から読んでください' \
                        '（値にバッククォートが入ると構文エラーで何も投稿されません）'
      end
    end

    assert_operator checked, :>, 0, 'github-script のステップが見つかりません（テストが空振りしています）'
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

  # 構文チェックだけでは、データ起因の破壊を捕まえられない。
  # script: 自体は正しくても、env: で渡ってくる値にバッククォートが混ざると
  # 実行時に壊れる（サーバーの説明文は servers.csv 由来なので実際に起こりうる）。
  #
  # そこで、env: の全キーに敵対的な値を入れて実際に走らせる。
  def test_github_script_blocks_survive_hostile_env_values
    skip 'node が無いため省略' if `which node`.strip.empty?

    # バッククォート・${}・不正なエスケープ・引用符。どれもテンプレートリテラルを壊す
    hostile = '`${process.exit(9)}\\u0041 "quote" \' + 1'

    checked = 0
    workflows.each do |path|
      each_step(path) do |job_name, index, step|
        next unless step['uses'].to_s.start_with?('actions/github-script')

        script = step.dig('with', 'script')
        next unless script.is_a?(String)

        env = (step['env'] || {}).keys.to_h { |key| [key, hostile] }
        next if env.empty?

        checked += 1
        assert_script_runs script, env, "#{File.basename(path)} の #{job_name} step#{index}"
      end
    end

    assert_operator checked, :>, 0, 'env: を持つ github-script が見つかりません（テストが空振りしています）'
  end

  # 上の検査が空振りしていないこと。
  # 壊れた script を渡したら落ちることを見ていないと、通っていても何も保証しない
  def test_the_hostile_value_check_actually_fails_on_a_broken_script
    skip 'node が無いため省略' if `which node`.strip.empty?

    # 値を env ではなくソースに埋め込んだ形（以前の ${{ }} と同じ壊れ方）
    broken = 'const comment = `値: ' + '`' + "`;\n" \
             'await github.rest.issues.createComment({ body: comment });'
    assert_raises(Minitest::Assertion) do
      assert_script_runs(broken, { 'HOSTILE' => 'x' }, '検査の自己確認')
    end
  end

  private

  # github / context を差し替えて script: を実行し、投稿される本文を取り出す
  def assert_script_runs(script, env, where)
    harness = <<~JS
      const bodies = [];
      const github = { rest: { issues: { createComment: async (o) => { bodies.push(o.body); return {}; } } } };
      const context = { repo: { owner: 'o', repo: 'r' }, issue: { number: 1 } };
      (async () => {
      #{script}
      })().then(() => { console.log(bodies.join('\\n')); })
          .catch((e) => { console.error(e && e.message); process.exit(1); });
    JS

    Tempfile.create(['github_script_run', '.js']) do |file|
      file.write(harness)
      file.flush
      out, err, status = Open3.capture3(env, 'node', file.path)
      assert status.success?, "#{where} の script: が実行時に壊れています\n#{err}"
      refute_empty out.strip, "#{where} が何も投稿していません"
    end
  end

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
