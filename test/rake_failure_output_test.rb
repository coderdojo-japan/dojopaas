require 'minitest/autorun'

# Rakefile の sh 呼び出しが満たすべき 2 つのこと
#
# 1. 失敗を自分で受けること（ブロックを渡す）
#    素の `sh "..."` は、コマンドが非 0 で終わると rake が RuntimeError を投げ、
#    「rake aborted!」と CI のランナー上の絶対パスを並べる。スクリプト自身が理由と
#    対処法を出しているので、その後ろに続くと読む人が本題を見つけにくい。
#    bot のコメントにはこの出力がそのまま載る（2026年10月7日に実際に載った）。
#
# 2. 引数をシェルに展開しないこと（配列形式で渡す）
#    1 本の文字列で渡すとシェルが解釈する。rake の引数は Issue からコピーした値が
#    入ることがあるので、`;` や `$(...)` が混ざると意図しないコマンドが走る。
#    配列形式なら、シェルを経由せずそのまま引数になる。
class RakeFailureOutputTest < Minitest::Test
  RAKEFILE = File.expand_path('../Rakefile', __dir__)

  SH_CALL = /^\s*sh[ (]/

  # 失敗しても困らない呼び出し。rake -T が失敗するなら Rakefile 自体が壊れていて、
  # その時こそトレースが欲しい
  ALLOWED_WITHOUT_BLOCK = ['sh "rake -T"'].freeze

  def sh_lines
    File.readlines(RAKEFILE).each_with_index.select { |line, _| SH_CALL.match?(line) }
  end

  def test_every_sh_call_handles_failure_itself
    lines = File.readlines(RAKEFILE)

    sh_lines.each do |line, index|
      next if ALLOWED_WITHOUT_BLOCK.any? { |allowed| line.include?(allowed) }

      # ブロックは同じ行か、引数が続く場合は次の行までに現れる（do / { のどちらでもよい）
      window = lines[index, 2].join
      assert_match(/(?:do|\{)\s*\|/, window,
                   "Rakefile:#{index + 1} の sh にブロックがありません。\n" \
                   "失敗時に rake のトレースが出ます。次の形にしてください:\n" \
                   '  sh(*cmd) { |ok, _res| exit 1 unless ok }')
    end
  end

  def test_no_shell_interpolation_in_sh_commands
    sh_lines.each do |line, index|
      # 配列形式（sh(*cmd) や sh('ruby', 'x', value)）は対象外。シェルを経由しない
      command = line[/\Ash[ (]\s*(["'].*)/, 1] || line[/^\s*sh[ (]\s*(["'][^,]*)/, 1]
      next if command.nil?

      refute_includes command, '#{',
                      "Rakefile:#{index + 1} の sh が引数をシェル文字列に展開しています。\n" \
                      "Issue からコピーした値が入ると、意図しないコマンドが走ります。\n" \
                      "配列で渡してください:\n" \
                      "  cmd = ['ruby', 'scripts/x.rb', value]\n" \
                      '  sh(*cmd) { |ok, _res| exit 1 unless ok }'
    end
  end

  # バッククォートもシェルを経由する。sh だけ見ていると、この形を見逃す
  # （2026年10月9日: prepare_deletion が未検証の IP をバッククォートに展開していた）
  BACKTICK_CALL = /^[^#]*`[^`]*\#\{/

  def test_no_shell_interpolation_in_backticks
    File.readlines(RAKEFILE).each_with_index do |line, index|
      refute_match(BACKTICK_CALL, line,
                   "Rakefile:#{index + 1} がバッククォートに値を展開しています。\n" \
                   "シェルが解釈するので、引数に `;` が混ざると別のコマンドが走ります。\n" \
                   "Open3 を配列で呼んでください:\n" \
                   "  out, status = Open3.capture2e('ruby', 'scripts/x.rb', value)")
    end
  end

  # 検査する対象が 1 つも無ければ、この検査は何も保証していない
  def test_the_check_finds_sh_calls
    assert_operator sh_lines.size, :>, 0, 'sh 呼び出しが見つかりません（検査が空振りしています）'
  end
end
