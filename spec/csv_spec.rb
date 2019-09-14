require 'rspec'
require 'csv'
INSTANCE_CSV = "servers.csv".freeze

describe 'valid CSV' do
    CSV.read(INSTANCE_CSV,headers: true).each do |line|
      it {
        expect(line['name']).to_not be nil
        expect(line['description']).to_not be nil
        expect(line['pubkey']).to_not be nil
        expect(line['branch']).to_not be nil
      }
  end
end
