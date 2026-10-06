require 'minitest/autorun'
require 'yaml'

# Issue フォームが GitHub に読まれる形になっているか
#
# フォームが壊れていると、GitHub はテンプレート選択に出さず、
# ?template=initialize_server.yml のリンクは空の Issue 作成画面に落ちる。
# 申請経路が消えるのに、Ruby 側のテストは全部通るので気づけない
class IssueTemplateTest < Minitest::Test
  TEMPLATE = File.expand_path('../.github/ISSUE_TEMPLATE/initialize_server.yml', __dir__)

  # 抽出側（scripts/initialize_server.rb）が見出しで探すラベル
  REQUIRED_LABELS = ['道場名', '申請者名', 'IPアドレス'].freeze

  def setup
    @form = YAML.load_file(TEMPLATE)
  end

  def test_yaml_is_parsable
    assert_kind_of Hash, @form
  end

  def test_has_title_and_labels
    assert_equal 'サーバーの初期化依頼', @form['title']
    assert_includes @form['labels'], 'サーバー初期化依頼'
  end

  # 抽出はラベル名で見出しを探すので、片方だけ変えると黙って読めなくなる
  def test_labels_match_what_the_extractor_looks_for
    form_labels = @form['body'].filter_map { |item| item.dig('attributes', 'label') }
    REQUIRED_LABELS.each { |label| assert_includes form_labels, label }
  end

  def test_required_fields_are_required
    @form['body'].each do |item|
      label = item.dig('attributes', 'label')
      next unless REQUIRED_LABELS.include?(label)

      assert item.dig('validations', 'required'), "#{label} は required にする"
    end
  end

  def test_field_ids_are_unique
    ids = @form['body'].filter_map { |item| item['id'] }
    assert_equal ids.uniq, ids
  end
end
