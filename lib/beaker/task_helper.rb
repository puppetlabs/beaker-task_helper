require 'beaker'
require 'beaker/task_helper/defaults'
require 'beaker/task_helper/bolt_helper'

# Beaker
module Beaker
  # A Task Helper
  module TaskHelper
    include Beaker::DSL

    def puppet_version
      (on default, puppet('--version')).output.chomp
    end

    def pe_install?
      ENV['PUPPET_INSTALL_TYPE'] =~ %r{pe}i if ENV['PUPPET_INSTALL_TYPE']
    end

    def run_puppet_access_login(user:, password: '~!@#$%^*-/ aZ', lifetime: '5y')
      on(master, puppet('access', 'login', '--username', user, '--lifetime', lifetime), stdin: password)
    end

    def run_task(task_name:, params: nil, password: DEFAULT_PASSWORD, host: nil, format: 'human')
      output = if pe_install?
                 host = master.hostname if host.nil?
                 run_puppet_task(task_name: task_name, params: params, host: host)
               else
                 host = 'localhost' if host.nil?
                 run_bolt_task(task_name: task_name, params: params, password: password, host: host)
               end

      if format == 'json'
        output = JSON.parse(output)
        output['items'][0]
      else
        output
      end
    end

    def run_puppet_task(task_name:, params: nil, host: 'localhost', format: 'human')
      args = ['task', 'run', task_name, '--nodes', host]
      if params.class == Hash
        args << '--params'
        args << params.to_json
      else
        args << params
      end
      if format == 'json'
        args << '--format'
        args << 'json'
      end
      on(master, puppet(*args), acceptable_exit_codes: [0, 1]).stdout
    end

    def expect_multiple_regexes(result:, regexes:)
      regexes.each do |regex|
        expect(result).to match(regex)
      end
    end

    def task_summary_line(total_hosts: 1, success_hosts: 1)
      "Job completed. #{success_hosts}/#{total_hosts} nodes succeeded|Ran on #{total_hosts} node"
    end
  end
end

include Beaker::TaskHelper
