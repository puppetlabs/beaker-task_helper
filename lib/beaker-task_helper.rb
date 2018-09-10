require 'beaker'

# Beaker task Helper
module Beaker::TaskHelper # rubocop:disable Style/ClassAndModuleChildren
  include Beaker::DSL

  def puppet_version
    (on default, puppet('--version')).output.chomp
  end

  DEFAULT_PASSWORD = if ENV.has_key?('BEAKER_password')
                       ENV['BEAKER_password']
                     elsif !defined?(default)
                       'root'
                     elsif default[:hypervisor] == 'vagrant'
                       'puppet'
                     else
                       'root'
                     end

  BOLT_VERSION = '0.21.8'.freeze

  def install_bolt_on(hosts, version = BOLT_VERSION, source = nil)
    unless default[:docker_image_commands].nil?
      if default[:docker_image_commands].to_s.include? 'yum'
        on(hosts, 'yum install -y make gcc ruby-devel', acceptable_exit_codes: [0, 1]).stdout
      elsif default[:docker_image_commands].to_s.include? 'apt-get'
        on(hosts, 'apt-get install -y make gcc ruby-dev', acceptable_exit_codes: [0, 1]).stdout
      end
    end

    Array(hosts).each do |host|
      pp = <<-INSTALL_BOLT_PP
  package { 'bolt' :
    provider => 'puppet_gem',
    ensure   => '#{version}',
INSTALL_BOLT_PP
      pp << "source   => '#{source}'" if source
      pp << '}'
      apply_manifest_on(host, pp)

      bolt_confdir = "#{on(host, 'echo $HOME').stdout.chomp}/.puppetlabs/bolt"
      on host, "mkdir -p #{bolt_confdir}"
      create_remote_file(host, "#{bolt_confdir}/analytics.yaml", { 'disabled' => true }.to_yaml)
    end
  end

  def pe_install?
    ENV['PUPPET_INSTALL_TYPE'] =~ %r{pe}i
  end

  def run_puppet_access_login(user:, password: '~!@#$%^*-/ aZ', lifetime: '5y')
    on(master, puppet('access', 'login', '--username', user, '--lifetime', lifetime), stdin: password)
  end

  #Setup ssh access between task runner and nodes
  #@param [Host] Task runner
  #@param [Array<Host> Nodes on which to run the task
  #
  #TODO: Implement on windows
  def setup_ssh_access(task_runner, nodes)
    ssh_dir_path = '/root/.ssh/'
    rsa_pub_path = "#{ssh_dir_path}/id_rsa.pub"

    on task_runner, "ssh-keygen -f #{ssh_dir_path}/id_rsa -t rsa -N ''"
    public_key = on(task_runner, "cat #{rsa_pub_path}").stdout
    create_remote_file(nodes, "#{rsa_pub_path}", public_key)
    on(nodes, "cat #{rsa_pub_path} >> #{ssh_dir_path}/authorized_keys")
  end

  def run_task(task_name:, params: nil, password: DEFAULT_PASSWORD, host: nil, format: 'human')
    output = if pe_install?
               host = master.hostname if host.nil?
               run_puppet_task(task_name: task_name, params: params, host: host, format: format)
             else
               host = 'localhost' if host.nil?
               run_bolt_task(task_name: task_name, params: params,
                             password: password, host: host, format: format)
             end

    if format == 'json'
      output = JSON.parse(output)
      output['items'][0]
    else
      output
    end
  end

  def run_bolt_task(task_name:, params: nil, password: DEFAULT_PASSWORD,
                    host: 'localhost', format: 'human', module_path: nil)
    module_path ||= default['distmoduledir']
    if fact_on(default, 'osfamily') == 'windows'
      bolt_path = '/cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/sys/ruby/bin/bolt.bat'
      if version_is_less('0.15.0', BOLT_VERSION)
        check = '--no-ssl'
      else
        check = '--insecure'
      end
    else
      bolt_path = '/opt/puppetlabs/puppet/bin/bolt'
      if version_is_less('0.15.0', BOLT_VERSION)
        check = '--no-host-key-check'
      else
        check = '--insecure'
      end
    end

    bolt_full_cli = "#{bolt_path} task run #{task_name} #{check} -m #{module_path} " \
                    "--nodes #{host} --password #{password}"
    bolt_full_cli << " --format #{format}" if format != 'human'
    bolt_full_cli << if params.class == Hash
                       " --params '#{params.to_json}'"
                     else
                       " #{params}"
                     end
    # windows is special
    if fact_on(default, 'osfamily') == 'windows'
      bolt_full_cli << ' --transport winrm --user Administrator'
    end
    puts "BOLT_CLI: #{bolt_full_cli}" if ENV['BEAKER_debug']
    on(default, bolt_full_cli, acceptable_exit_codes: [0, 1, 2]).stdout
  end

  def run_puppet_task(task_name:, params: nil, host: 'localhost', format: 'human')
    args = ['task', 'run', task_name, '--nodes', host]
    if params.class == Hash
      args << '--params'
      args << params.to_json
    else
      args << params
    end
    if format != 'human'
      args << '--format'
      args << format
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

include Beaker::TaskHelper
