require 'minitest/autorun'
require 'csv'

class CSVTest < Minitest::Test
  INSTANCE_CSV = "servers.csv".freeze

  def test_csv_has_required_headers
    csv = CSV.read(INSTANCE_CSV, headers: true)
    
    # ヘッダーの存在確認
    assert csv.headers.include?('name'), "CSV must have 'name' header"
    assert csv.headers.include?('description'), "CSV must have 'description' header"
    assert csv.headers.include?('pubkey'), "CSV must have 'pubkey' header"
    assert csv.headers.include?('branch'), "CSV must have 'branch' header"
  end

  def test_csv_fields_are_not_nil
    CSV.read(INSTANCE_CSV, headers: true).each_with_index do |line, index|
      # 各行の必須フィールドが存在することを確認
      refute_nil line['name'], "Row #{index + 1}: name must not be nil"
      refute_nil line['description'], "Row #{index + 1}: description must not be nil"
      refute_nil line['pubkey'], "Row #{index + 1}: pubkey must not be nil"
      refute_nil line['branch'], "Row #{index + 1}: branch must not be nil"
    end
  end

  def test_csv_fields_are_not_empty
    CSV.read(INSTANCE_CSV, headers: true).each_with_index do |line, index|
      # 各フィールドが空文字でないことを確認
      refute_empty line['name'].to_s.strip, "Row #{index + 1}: name must not be empty"
      refute_empty line['description'].to_s.strip, "Row #{index + 1}: description must not be empty"
      refute_empty line['pubkey'].to_s.strip, "Row #{index + 1}: pubkey must not be empty"
      refute_empty line['branch'].to_s.strip, "Row #{index + 1}: branch must not be empty"
    end
  end

  def test_pubkey_format
    CSV.read(INSTANCE_CSV, headers: true).each_with_index do |line, index|
      pubkey = line['pubkey']
      next if pubkey.nil? || pubkey.empty?
      
      # SSH公開鍵の基本的なフォーマットチェック
      assert_match(/^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256)/, pubkey,
                   "Row #{index + 1}: pubkey must be a valid SSH public key")
    end
  end

  def test_branch_is_not_empty
    CSV.read(INSTANCE_CSV, headers: true).each_with_index do |line, index|
      branch = line['branch']
      
      # branchフィールドが空でないことを確認（各道場固有のブランチ名を許可）
      refute_nil branch, "Row #{index + 1}: branch must not be nil"
      refute_empty branch.to_s.strip, "Row #{index + 1}: branch must not be empty"
    end
  end
end