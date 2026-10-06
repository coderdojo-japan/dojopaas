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
  # @param csv_names [Array<String>] servers.csv の name
  # @param live_names [Array<String>] さくらのクラウドにあるサーバー名
  # @return [Array<String>] 行はあるのにサーバーが無い name
  def self.missing(csv_names, live_names)
    live = live_names.map { |n| n.to_s.strip }
    csv_names.map { |n| n.to_s.strip }.reject { |n| n.empty? || live.include?(n) }
  end

  def self.message(missing_names)
    "作成できなかったサーバーが #{missing_names.size} 台あります: #{missing_names.join(', ')}"
  end
end

if __FILE__ == $PROGRAM_NAME
  require 'csv'
  require_relative 'sakura_server_user_agent'

  csv_names  = CSV.read('servers.csv', headers: true).map { |row| row['name'] }
  live_names = SakuraServerUserAgent.new.get_servers['Servers'].map { |s| s['Name'] }

  missing = VerifyCreated.missing(csv_names, live_names)
  if missing.empty?
    puts "servers.csv の #{csv_names.size} 行は、すべてサーバーがあります"
  else
    abort VerifyCreated.message(missing)
  end
end
