require 'minitest/autorun'

# スクリプトを呼ぶ rake タスクが、失敗時に rake のトレースを出さないこと
#
# 素の `sh "ruby scripts/..."` は、スクリプトが非 0 で終わると rake が RuntimeError を投げ、
# 「rake aborted!」と CI のランナー上の絶対パスを並べる。スクリプト自身が理由と対処法を
# 出しているので、その後ろに続くと読む人が本題を見つけにくい。
#
# bot のコメントにはこの出力がそのまま載るため、Issue を出した人の目にも入る
# （2026年10月7日に実際に載った）。
#
# ブロックを渡して自分で exit すれば、rake は SystemExit を黙って再送出する。
# 終了コードはそのまま残るので、呼び出し側の成功・失敗の判定は変わらない。
class RakeFailureOutputTest < Minitest::Test
  RAKEFILE = File.expand_path('../Rakefile', __dir__)

  # scripts/ 配下を呼ぶ sh。ここが失敗するとユーザーの目に入る
  SCRIPT_CALL = /^\s*sh[ (]["']ruby scripts\//

  def test_script_calls_handle_failure_themselves
    lines = File.readlines(RAKEFILE)

    lines.each_with_index do |line, index|
      next unless SCRIPT_CALL.match?(line)

      # ブロックは同じ行か、引数が続く場合は次の行までに現れる（do / { のどちらでもよい）
      window = lines[index, 2].join
      assert_match(/(?:do|\{)\s*\|/, window,
                   "Rakefile:#{index + 1} の sh にブロックがありません。\n" \
                   "失敗時に rake のトレースが出ます。次の形にしてください:\n" \
                   '  sh("...", verbose: false) { |ok, _res| exit 1 unless ok }')
    end
  end

  # 検査する対象が 1 つも無ければ、この検査は何も保証していない
  def test_the_check_finds_script_calls
    found = File.readlines(RAKEFILE).count { |line| SCRIPT_CALL.match?(line) }
    assert_operator found, :>, 0, 'scripts/ を呼ぶ sh が見つかりません（検査が空振りしています）'
  end
end
