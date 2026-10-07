require 'minitest/autorun'
require 'yaml'
require_relative '../scripts/initialize_server'

# Issue フォームが GitHub に読まれる形になっているか
#
# フォームが壊れていると、GitHub はテンプレート選択に出さず、
# ?template=initialize_server.yml のリンクは空の Issue 作成画面に落ちる。
# 依頼の経路が消えるのに、Ruby 側のテストは全部通るので気づけない。
#
# GitHub の構文チェックは default branch に乗ってからしか走らないため、
# 「黙って捨てられる条件」をここで先に見る
# https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema
module IssueFormRules
  TYPES = %w[markdown input textarea dropdown checkboxes].freeze

  # type ごとに attributes の下で必須の項目
  REQUIRED_ATTRIBUTES = {
    'markdown'   => 'value',
    'input'      => 'label',
    'textarea'   => 'label',
    'dropdown'   => 'label',
    'checkboxes' => 'label'
  }.freeze

  ID_PATTERN = /\A[a-zA-Z0-9_-]+\z/

  # GitHub がフォームとして受け付けない点を列挙する（空なら問題なし）
  def self.problems_in(form)
    return ['トップレベルが Hash ではありません'] unless form.is_a?(Hash)

    problems = []
    problems << 'name がありません'        if form['name'].to_s.empty?
    problems << 'description がありません' if form['description'].to_s.empty?

    body = form['body']
    return problems + ['body が配列ではありません'] unless body.is_a?(Array)

    problems << 'body が空です' if body.empty?

    # markdown は表示専用なので、入力欄が 1 つも無いフォームは成立しない
    fields = body.select { |item| item.is_a?(Hash) && item['type'] != 'markdown' }
    problems << 'body に入力欄（markdown 以外）がありません' if !body.empty? && fields.empty?

    body.each_with_index { |item, i| problems.concat(problems_in_item(item, i + 1)) }
    problems.concat(duplicate_id_problems(body))
    problems
  end

  def self.problems_in_item(item, position)
    return ["body[#{position}] が Hash ではありません"] unless item.is_a?(Hash)

    type = item['type']
    return ["body[#{position}] の type が #{type.inspect} です（#{TYPES.join(' / ')} のいずれか）"] unless TYPES.include?(type)

    problems = []
    needed = REQUIRED_ATTRIBUTES.fetch(type)
    if item.dig('attributes', needed).to_s.empty?
      problems << "body[#{position}]（#{type}）に attributes.#{needed} がありません"
    end

    if %w[dropdown checkboxes].include?(type) && !item.dig('attributes', 'options').is_a?(Array)
      problems << "body[#{position}]（#{type}）に attributes.options がありません"
    end

    id = item['id']
    problems << "id #{id.inspect} に使えない文字が入っています" if id && !ID_PATTERN.match?(id.to_s)

    required = item.dig('validations', 'required')
    unless required.nil? || [true, false].include?(required)
      problems << "body[#{position}] の validations.required が真偽値ではありません"
    end

    problems
  end

  def self.duplicate_id_problems(body)
    ids = body.filter_map { |item| item['id'] if item.is_a?(Hash) }
    ids.tally.filter_map { |id, count| "id #{id.inspect} が #{count} 回使われています" if count > 1 }
  end
end

class IssueTemplateTest < Minitest::Test
  TEMPLATE = File.expand_path('../.github/ISSUE_TEMPLATE/initialize_server.yml', __dir__)

  # 抽出側（scripts/initialize_server.rb）が見出しで探すラベル
  # 抽出側の定数をそのまま使う。手で写すと、片方だけ変えた時に気づけない
  REQUIRED_LABELS = [ServerInitializer::FORM_DOJO_LABEL,
                     '道場代表者の氏名',
                     ServerInitializer::FORM_IP_LABEL].freeze

  def setup
    @form = YAML.load_file(TEMPLATE)
  end

  def test_yaml_is_parsable
    assert_kind_of Hash, @form
  end

  def test_form_satisfies_github_schema
    assert_empty IssueFormRules.problems_in(@form)
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

  # 同じラベルが 2 つあると、見出しで探す抽出がどちらを指すか決まらない
  def test_labels_are_unique
    form_labels = @form['body'].filter_map { |item| item.dig('attributes', 'label') }
    assert_equal form_labels.uniq, form_labels
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

# 上の検査が本当に効くかを確かめる
#
# 「壊れたフォームを渡したら落ちる」ことを見ていない検査は、
# 通っていても何も保証しない（実際、フォームが壊れていた間も Ruby 側は全部緑だった）
class IssueFormRulesTest < Minitest::Test
  VALID = {
    'name' => 'テスト', 'description' => '説明',
    'body' => [{ 'type' => 'input', 'id' => 'ip',
                 'attributes' => { 'label' => 'IPアドレス' },
                 'validations' => { 'required' => true } }]
  }.freeze

  def test_valid_form_has_no_problems
    assert_empty IssueFormRules.problems_in(VALID)
  end

  def test_missing_name_is_detected
    refute_empty IssueFormRules.problems_in(VALID.reject { |key, _| key == 'name' })
  end

  def test_missing_description_is_detected
    refute_empty IssueFormRules.problems_in(VALID.reject { |key, _| key == 'description' })
  end

  def test_unknown_type_is_detected
    broken = deep_dup(VALID)
    broken['body'][0]['type'] = 'text'
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_input_without_label_is_detected
    broken = deep_dup(VALID)
    broken['body'][0]['attributes'] = {}
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_markdown_without_value_is_detected
    broken = deep_dup(VALID)
    broken['body'][0] = { 'type' => 'markdown', 'attributes' => {} }
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_dropdown_without_options_is_detected
    broken = deep_dup(VALID)
    broken['body'][0] = { 'type' => 'dropdown', 'attributes' => { 'label' => '選択' } }
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_invalid_id_is_detected
    broken = deep_dup(VALID)
    broken['body'][0]['id'] = 'ip address'
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_duplicate_id_is_detected
    broken = deep_dup(VALID)
    broken['body'] << deep_dup(VALID)['body'][0]
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_empty_body_is_detected
    broken = deep_dup(VALID)
    broken['body'] = []
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_body_that_is_not_an_array_is_detected
    broken = deep_dup(VALID)
    broken['body'] = 'input'
    refute_empty IssueFormRules.problems_in(broken)
  end

  def test_checkboxes_without_options_is_detected
    broken = deep_dup(VALID)
    broken['body'][0] = { 'type' => 'checkboxes', 'attributes' => { 'label' => '同意' } }
    refute_empty IssueFormRules.problems_in(broken)
  end

  # markdown だけの body は GitHub が受け取らない（入力欄が 1 つも無いため）
  def test_markdown_only_body_is_detected
    broken = deep_dup(VALID)
    broken['body'] = [{ 'type' => 'markdown', 'attributes' => { 'value' => '説明' } }]
    refute_empty IssueFormRules.problems_in(broken)
  end

  private

  def deep_dup(value)
    Marshal.load(Marshal.dump(value))
  end
end
