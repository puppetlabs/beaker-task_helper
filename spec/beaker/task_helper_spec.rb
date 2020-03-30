require 'spec_helper_acceptance'

RSpec.describe Beaker::TaskHelper do
  context 'returns correct summary line' do
    it 'with default values' do
      expect(task_summary_line).to eq 'Job completed. 1/1 targets succeeded|Ran on 1 target'
    end
    it 'with 3 total hosts and 2 success' do
      expect(task_summary_line(total_hosts: 3, success_hosts: 2))
        .to eq 'Job completed. 2/3 targets succeeded|Ran on 3 target'
    end
  end
end
