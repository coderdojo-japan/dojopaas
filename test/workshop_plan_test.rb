require 'minitest/autorun'
require_relative '../scripts/sakura_server_user_agent'

# branch 名が「隠しコマンド」として働き、ワークショップ用サーバーだけ
# 高スペックで作られることを検証する
class WorkshopPlanTest < Minitest::Test
  def test_workshop_branch_with_date_gets_workshop_plan
    assert_equal SakuraServerUserAgent::WORKSHOP_PLAN,
                 SakuraServerUserAgent.plan_for('workshop-20261115'),
                 "workshop-<yyyymmdd> だけが高スペックの合図"
  end

  # 日付が無いものは発動しない（期限が分からないサーバーを作らない）
  def test_branches_without_a_date_get_default_plan
    ['workshop', 'workshop-', 'workshop-2026', 'workshop-2026-11-15'].each do |branch|
      assert_equal SakuraServerUserAgent::DEFAULT_PLAN,
                   SakuraServerUserAgent.plan_for(branch),
                   "'#{branch}' は日付の形が違うので発動しない"
    end
  end

  # 表記の揺れも発動しない（揺れは CSV のテストで止める）
  def test_case_variants_get_default_plan
    assert_equal SakuraServerUserAgent::DEFAULT_PLAN,
                 SakuraServerUserAgent.plan_for('Workshop-20261115')
  end

  def test_regular_branch_gets_default_plan
    assert_equal SakuraServerUserAgent::DEFAULT_PLAN,
                 SakuraServerUserAgent.plan_for('japan'),
                 "ふだんの Dojo サーバーは 1コア1GB のまま"
  end

  # 既存の79行を巻き込まないこと
  def test_lookalike_branches_get_default_plan
    ['workshops-20261115', 'workshopfoo', 'naha-workshop', 'pre-workshop-20261115', ''].each do |branch|
      assert_equal SakuraServerUserAgent::DEFAULT_PLAN,
                   SakuraServerUserAgent.plan_for(branch),
                   "'#{branch}' では発動しない"
    end
  end

  # 惜しい書き方の一覧。いずれも発動せず、CSV のテストで PR が落ちる
  def test_near_miss_branches_do_not_fire
    [
      "workshop_20261013",   # 区切りがアンダースコア
      "workshop-2026-10-13", # ハイフン区切りの日付
      "workshop-261013",     # 6桁
      "workshop-202610131",  # 9桁
      "WORKSHOP-20261013",   # 大文字
    ].each do |branch|
      assert_equal SakuraServerUserAgent::DEFAULT_PLAN,
                   SakuraServerUserAgent.plan_for(branch),
                   "#{branch} では発動しない"
    end
  end

  def test_nil_branch_gets_default_plan
    assert_equal SakuraServerUserAgent::DEFAULT_PLAN, SakuraServerUserAgent.plan_for(nil)
  end

  # servers.csv には前後に空白が入った行が実在する（55行目の branch など）
  def test_branch_with_surrounding_spaces_still_fires
    ['workshop-20261115 ', ' workshop-20261115', '  workshop-20261115  '].each do |branch|
      assert_equal SakuraServerUserAgent::WORKSHOP_PLAN,
                   SakuraServerUserAgent.plan_for(branch),
                   "前後の空白では判定が変わらない: #{branch.inspect}"
    end
  end

  def test_workshop_plan_values
    plan = SakuraServerUserAgent::WORKSHOP_PLAN
    assert_equal 8, plan[:CPU]
    assert_equal 8192, plan[:MemoryMB]
  end

  def test_workshop_branch_exposes_the_date
    assert_equal '20261115', SakuraServerUserAgent.workshop_date('workshop-20261115')
    assert_nil SakuraServerUserAgent.workshop_date('japan')
    assert_nil SakuraServerUserAgent.workshop_date('workshop')
  end
end

# 実際に送られるリクエスト本文を捕まえて、隠しコマンドが届いていることを確かめる
class CapturingAgent < SakuraServerUserAgent
  attr_reader :sent

  def initialize(**kwargs)
    super(**kwargs)
    @sent = []
  end

  private

  def send_request(http_method, path, query)
    @sent << { method: http_method, path: path, query: query }
    { 'Server' => { 'ID' => 'dummy-id' } }
  end
end

class WorkshopPlanRequestTest < Minitest::Test
  def plan_sent_for(branch)
    agent = CapturingAgent.new(name: 'test-server', description: 'テスト', tags: ['dojopaas', branch])
    agent.create_server_instance
    agent.sent.first[:query][:Server][:ServerPlan]
  end

  def test_workshop_branch_reaches_the_request_body
    assert_equal({ CPU: 8, MemoryMB: 8192, Generation: 100 }, plan_sent_for('workshop-20261115'))
  end

  def test_regular_branch_keeps_the_current_spec
    assert_equal({ CPU: 1, MemoryMB: 1024, Generation: 100 }, plan_sent_for('naha'))
  end
end
