require 'spec_helper_acceptance'

RSpec.describe Beaker::I18nHelper do
  it 'has a version number' do
    expect(Beaker::I18nHelper::VERSION).not_to be nil
  end
  describe '#validate_lang_string' do
    context 'with invalid args' do
      ['jaJP', 'ja_JP-utf8', 'foo', '123'].each do |lang|
        it_behaves_like 'an invalid lang string', lang
      end
    end
    context 'with valid args' do
      ['ja_JP', 'ja-JP', 'ja_JP.utf-8', 'ja-JP.UTF-8'].each do |lang|
        it_behaves_like 'a valid lang string', lang
      end
    end
  end
end

RSpec.describe Beaker::TaskHelper do
  it 'returns correct summary line' do
    describe 'with default values' do
      expect(task_summary_line).to be 'Job completed. 1/1 nodes succeeded|Ran on 1 node'
    end
    describe 'with 3 total hosts and 2 success' do
      expect(task_summary_line(3, 2)).to be 'Job completed. 2/3 nodes succeeded|Ran on 3 node'
    end
  end
end
