# servers.csv の行に対して、サーバーが実際にあるかを確かめる
#
# 作成の各ステップは例外を puts で握りつぶして進むため、途中で失敗しても
# deploy.rb は終了コード0で終わる。「終了したか」ではなく「実際にあるか」で
# 判定しないと、作られなかったことに誰も気づけない。
#
# 公開（gh-pages への push）の後に実行する。1台失敗しただけで、
# 成功した他の道場の IP まで公開されなくなるのを避けるため。
#
# 使い方: bundle exec ruby scripts/verify_created.rb
module VerifyCreated
  # 失敗したときに、通知のステップへ名前を渡すための置き場
  MISSING_FILE = 'tmp/missing_servers.txt'.freeze

  # @param csv_names [Array<String>] servers.csv の name
  # @param live_names [Array<String>] さくらのクラウドにあるサーバー名
  # @return [Array<String>] 行はあるのにサーバーが無い name
  def self.missing(csv_names, live_names)
    live = live_names.map { |n| n.to_s.strip }
    csv_names.map { |n| n.to_s.strip }.reject { |n| n.empty? || live.include?(n) }
  end

  # サーバーの一覧（API の応答）から判定する
  # 名前はあるが IP が無いものも「作れていない」と見なす
  # （サーバー本体の作成後、NIC やディスクで失敗すると起きる）
  # @param servers [Array<Hash>] さくらのクラウドの Servers 配列
  def self.missing_from(csv_names, servers)
    usable = servers.reject { |s| s.dig('Interfaces', 0, 'IPAddress').to_s.strip.empty? }
                    .map { |s| s['Name'] }
    missing(csv_names, usable)
  end

  # 失敗したときに、通知のステップへ名前を渡す
  # 置き場のディレクトリは CI に無い（tmp/ は gitignore）ので作ってから書く
  def self.record_missing(missing_names, path: MISSING_FILE)
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, missing_names.join("\n"))
    path
  end

  def self.message(missing_names)
    "作成できなかったサーバーが #{missing_names.size} 台あります: #{missing_names.join(', ')}"
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'csv'
  require_relative 'sakura_server_user_agent'

  csv_names = CSV.read('servers.csv', headers: true).map { |row| row['name'] }
  servers   = SakuraServerUserAgent.new.get_servers['Servers']

  missing = VerifyCreated.missing_from(csv_names, servers)
  if missing.empty?
    puts "servers.csv の #{csv_names.size} 行は、すべてサーバーがあります"
  else
    # 次のステップ（通知）が名前を使えるように書き出す
    VerifyCreated.record_missing(missing)
    abort VerifyCreated.message(missing)
  end
end
