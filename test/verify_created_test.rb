require 'minitest/autorun'
require_relative '../scripts/verify_created'

# 作成できたかどうかは、終了コードではなく「実際にあるか」で判定する
#
# 作成の各ステップは例外を puts で握りつぶして進むため、
# 失敗しても deploy.rb は終了コード0で終わる（通知が鳴らない）
class VerifyCreatedTest < Minitest::Test
  def test_no_missing_when_all_exist
    assert_empty VerifyCreated.missing(%w[coderdojo-naha coderdojo-japan], %w[coderdojo-japan coderdojo-naha])
  end

  def test_lists_rows_without_a_server
    missing = VerifyCreated.missing(%w[coderdojo-naha coderdojo-japan], %w[coderdojo-japan])
    assert_equal ['coderdojo-naha'], missing
  end

  def test_ignores_servers_without_a_row
    # servers.csv に無いサーバー（過去の残り）は、ここでは問題にしない
    assert_empty VerifyCreated.missing(%w[coderdojo-japan], %w[coderdojo-japan coderdojo-old])
  end

  def test_ignores_surrounding_spaces
    assert_empty VerifyCreated.missing([' coderdojo-naha '], ['coderdojo-naha'])
  end

  # 名前だけあって IP が無いサーバーは「作れていない」と見なす
  # （サーバー本体の作成後、NIC やディスクで失敗すると起きる）
  def test_servers_without_an_ip_count_as_missing
    live = [{ 'Name' => 'coderdojo-naha', 'Interfaces' => [] }]
    assert_equal ['coderdojo-naha'], VerifyCreated.missing_from(%w[coderdojo-naha], live)
  end

  def test_servers_with_an_ip_are_fine
    live = [{ 'Name' => 'coderdojo-naha', 'Interfaces' => [{ 'IPAddress' => '192.0.2.1' }] }]
    assert_empty VerifyCreated.missing_from(%w[coderdojo-naha], live)
  end

  def test_message_names_the_rows
    message = VerifyCreated.message(%w[coderdojo-naha coderdojo-ome])
    assert_includes message, 'coderdojo-naha'
    assert_includes message, 'coderdojo-ome'
    assert_includes message, '2'
  end
end
