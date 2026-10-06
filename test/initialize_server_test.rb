require 'minitest/autorun'
require_relative '../scripts/initialize_server'

# 削除の関門: IP で見つけたサーバー名と、人が書いた名前が一致するか
#
# Issue に貼られた IP が別の道場のものだった場合、ここだけが機械的に止める
# （--force でも飛ばせない）
class DeletionNameGuardTest < Minitest::Test
  def test_matching_name_passes
    assert ServerInitializer.name_matches?('coderdojo-naha', 'coderdojo-naha')
  end

  def test_surrounding_spaces_are_ignored
    assert ServerInitializer.name_matches?('coderdojo-naha', ' coderdojo-naha ')
  end

  def test_different_dojo_is_rejected
    refute ServerInitializer.name_matches?('coderdojo-naha', 'coderdojo-japan'),
           '別の道場の名前では通さない'
  end

  def test_partial_name_is_rejected
    refute ServerInitializer.name_matches?('coderdojo-naha', 'naha'),
           '部分一致では通さない'
    refute ServerInitializer.name_matches?('coderdojo-naha-workshop', 'coderdojo-naha'),
           'ワークショップ用サーバーと通常のサーバーを取り違えない'
  end

  def test_case_difference_is_rejected
    refute ServerInitializer.name_matches?('coderdojo-naha', 'CoderDojo-Naha')
  end

  # 名前を省略した呼び出し（従来の force だけの形）は通さない
  def test_missing_name_is_rejected
    refute ServerInitializer.name_matches?('coderdojo-naha', nil)
    refute ServerInitializer.name_matches?('coderdojo-naha', '')
    refute ServerInitializer.name_matches?('coderdojo-naha', '   ')
    refute ServerInitializer.name_matches?('coderdojo-naha', 'true'),
           '以前の force 引数をそのまま渡しても削除されない'
  end
end
