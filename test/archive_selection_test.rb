require 'minitest/autorun'
require 'stringio'
require_relative '../scripts/deploy'

# get_archives だけを返す差し替え（API は呼ばない）
class ArchiveListAgent
  def initialize(names)
    @names = names
  end

  def get_archives
    { 'Archives' => @names.each_with_index.map { |name, i| { 'ID' => "ID-#{i}", 'Name' => name } } }
  end
end

class ArchiveSelectionTest < Minitest::Test
  # 2026年10月19日に石狩第二ゾーンの API が返した並び（Ubuntu の行だけ）
  ARCHIVES = [
    'Ubuntu Server 22.04.4 LTS 64bit',
    'Ubuntu Server 22.04.5 LTS 64bit',
    'Ubuntu Server 24.04.1 LTS 64bit',
    'Ubuntu Server 24.04.2 LTS 64bit',
    'Ubuntu Server 26.04 LTS 64bit',
    'Ubuntu Server 24.04.1 LTS 64bit (cloudimg)',
    'Ubuntu Server 24.04.2 LTS 64bit (cloudimg)',
    'CData Sync v25.3(Ubuntu 24.04.2 LTS 64bit)',
  ].freeze

  def select(names)
    cli = CoderDojoSakuraCLI.new([])
    cli.instance_variable_set(:@ssua, ArchiveListAgent.new(names))
    $stdout = StringIO.new
    cli.send(:initial_archive_id)
  ensure
    $stdout = STDOUT
  end

  # 一覧で先に来る点リリースではなく、24.04 の最新の点リリースを選ぶ
  def test_selects_the_latest_point_release_of_24_04
    assert_equal 'ID-3', select(ARCHIVES)
  end

  # 点リリースの無い 24.04 と点リリースがあれば、点リリースの方が新しい
  def test_point_release_is_newer_than_the_initial_release
    assert_equal 'ID-1', select(['Ubuntu Server 24.04 LTS 64bit', 'Ubuntu Server 24.04.1 LTS 64bit'])
  end
end
