require 'minitest/autorun'

# このテストが require できること自体が、deploy.rb が読み込みだけでは
# 実行されない（= rake server:create が全件 deploy を起こさない）証拠になる
require_relative '../scripts/deploy'
require_relative '../scripts/sakura_server_user_agent'

# API を呼ばずに、送られるリクエストを捕まえるための差し替え
class RecordingAgent < SakuraServerUserAgent
  attr_reader :calls
  attr_accessor :fail_server_post

  def initialize(**kwargs)
    super(**kwargs)
    @calls = []
  end

  def server_id = @server_id
  def interface_id = @interface_id

  private

  def send_request(http_method, path, query)
    @calls << "#{http_method.upcase} #{path}"
    raise 'POST server failed' if path == 'server' && http_method == 'post' && fail_server_post

    case path
    when 'server'          then { 'Server' => { 'ID' => 'NEW-SERVER' } }
    when 'interface'       then { 'Interface' => { 'ID' => 'IF' } }
    when %r{\Ainterface/}  then { 'Interface' => { 'ID' => 'IF', 'Server' => { 'ID' => 'NEW-SERVER' } } }
    else {}
    end
  end
end

class DeployRobustnessTest < Minitest::Test
  # 1行目の作成に成功した後、2行目の作成が失敗したとき、
  # 2行目の処理が1行目のサーバーに向かってはいけない
  def test_failed_creation_does_not_touch_the_previous_server
    agent = RecordingAgent.new(name: 'first', description: '1行目', pubkey: 'ssh-ed25519 AAAA')
    agent.create_server_instance
    assert_equal 'NEW-SERVER', agent.server_id, '1行目の ID を覚えている'

    agent.fail_server_post = true
    assert_raises(RuntimeError, '失敗は握りつぶさず、その場で落ちる') do
      agent.create(name: 'second', description: '2行目', pubkey: 'ssh-ed25519 AAAA', tag: 'naha')
    end

    refute_includes agent.calls, 'POST interface', '失敗後に NIC を作りに行かない'
    assert_nil agent.server_id, '前の行の ID を引き継がない'
  end

  # create は毎回 ID を初期化する
  def test_create_resets_ids
    agent = RecordingAgent.new(name: 'first', description: '1行目', pubkey: 'ssh-ed25519 AAAA')
    agent.create_server_instance
    agent.fail_server_post = true
    agent.create(name: 'second', description: '2行目', pubkey: 'ssh-ed25519 AAAA', tag: 'naha') rescue nil
    assert_nil agent.interface_id
  end
end

class InstanceRowTest < Minitest::Test
  def setup
    @cli = CoderDojoSakuraCLI.new([])
  end

  def test_row_has_name_ip_and_description
    server = { 'Name' => 'coderdojo-naha', 'Description' => '説明',
               'Interfaces' => [{ 'IPAddress' => '192.0.2.10' }] }
    assert_equal ['coderdojo-naha', '192.0.2.10', '説明'], @cli.instance_row(server)
  end

  # NIC の無いサーバーが1台あるだけで、全 Dojo の deploy が止まってはいけない
  def test_row_tolerates_a_server_without_an_interface
    server = { 'Name' => 'coderdojo-broken', 'Description' => '説明', 'Interfaces' => [] }
    assert_equal ['coderdojo-broken', nil, '説明'], @cli.instance_row(server)
  end
end
