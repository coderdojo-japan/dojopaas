require 'minitest/autorun'
require_relative '../scripts/sakura_server_user_agent'

class IPValidationTest < Minitest::Test
  def test_valid_ip_addresses
    # 正常なIPアドレス
    assert SakuraServerUserAgent.valid_ip_address?('192.168.1.1')
    assert SakuraServerUserAgent.valid_ip_address?('10.0.0.1')
    assert SakuraServerUserAgent.valid_ip_address?('153.127.192.200')
    assert SakuraServerUserAgent.valid_ip_address?('8.8.8.8')
  end

  def test_invalid_ip_addresses
    # 無効なIPアドレス
    refute SakuraServerUserAgent.valid_ip_address?('999.999.999.999')
    refute SakuraServerUserAgent.valid_ip_address?('not.an.ip.address')
    refute SakuraServerUserAgent.valid_ip_address?('192.168.1')
    refute SakuraServerUserAgent.valid_ip_address?('192.168.1.1.1')
    refute SakuraServerUserAgent.valid_ip_address?('')
    refute SakuraServerUserAgent.valid_ip_address?(nil)
  end

  def test_normalize_ip_address
    # 正規化のテスト
    assert_equal '192.168.1.1', SakuraServerUserAgent.normalize_ip_address('192.168.1.1')
    assert_equal '10.0.0.1', SakuraServerUserAgent.normalize_ip_address('10.0.0.1')
    
    # 無効な入力
    assert_nil SakuraServerUserAgent.normalize_ip_address('192.168.001.001')  # ゼロ埋めは無効
    assert_nil SakuraServerUserAgent.normalize_ip_address('invalid')
    assert_nil SakuraServerUserAgent.normalize_ip_address(nil)
    assert_nil SakuraServerUserAgent.normalize_ip_address('')
  end

  def test_edge_cases
    # エッジケース
    assert SakuraServerUserAgent.valid_ip_address?('0.0.0.0')
    assert SakuraServerUserAgent.valid_ip_address?('255.255.255.255')
    refute SakuraServerUserAgent.valid_ip_address?('256.1.1.1')
    refute SakuraServerUserAgent.valid_ip_address?('-1.1.1.1')
  end
end