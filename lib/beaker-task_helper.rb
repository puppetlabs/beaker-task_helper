require 'beaker'

# Beaker task Helper
module Beaker::TaskHelper # rubocop:disable Style/ClassAndModuleChildren
  include Beaker::DSL

  def puppet_version
    (on default, puppet('--version')).output.chomp
  end

  def bolt_path
    if fact_on(default, 'os.family') == 'windows'
      if ENV['BEAKER_PUPPET_COLLECTION'].nil? || %w[pc1 puppet5 puppet6].include?(ENV['BEAKER_PUPPET_COLLECTION'])
        '/cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/sys/ruby/bin/bolt.bat'
      else
        '/cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/puppet/bin/bolt.bat'
      end
    else
      # If bolt was installed as a package
      if File.exist?('/opt/puppetlabs/puppet/bin/bolt')
        '/opt/puppetlabs/puppet/bin/bolt'
      else
      # Or as a gem
        'bolt'
      end
    end
  end

  # Returns the version of Bolt installed on the beakerhost. Used to determine
  # which inventory file version to generate.
  #
  def self.bolt_version(beakerhost = nil)
    return ENV['BEAKER_BOLT_VERSION'] if ENV['BEAKER_BOLT_VERSION']

    beakerhost ||= default
    begin
      on(beakerhost, "#{bolt_path} --version")
    rescue Beaker::Host::CommandFailure
      # If bolt isn't installed, default to 1.18.0 which is the latest version
      # to support only v1 inventory
      '1.18.0'
    end
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

  DEFAULT_BOLT_VERSION = if ENV['BEAKER_PUPPET_COLLECTION'].nil? || ENV['BEAKER_PUPPET_COLLECTION'] == 'pc1'
                           # puppet4 uses an older version of ruby (2.1.9) that bolt has stopped supporting
                           '0.16.1'.freeze
                         else
                           # CODEREVIEW: Can we update this to 1.x?
                           '0.23.0'.freeze
                         end

  def install_bolt_on(hosts, version = DEFAULT_BOLT_VERSION, source = nil)
    unless default[:docker_image_commands].nil?
      if default[:docker_image_commands].to_s.include? 'yum'
        on(hosts, 'yum install -y make gcc ruby-devel', acceptable_exit_codes: [0, 1]).stdout
      elsif default[:docker_image_commands].to_s.include? 'apt-get'
        on(hosts, 'apt-get install -y make gcc ruby-dev', acceptable_exit_codes: [0, 1]).stdout
      end
    end

    Array(hosts).each do |host|

      # Work around for BOLT-845
      pp0 = <<-INSTALL_FFI_PP
  package { 'ffi' :
    provider => 'puppet_gem',
    ensure   => '1.9.18', }
INSTALL_FFI_PP

      apply_manifest_on(host, pp0) if fact_on(host, 'os.family') == 'RedHat' && fact_on(host, 'os.release.major') == '5'

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

  def target_flag(host=default)
    if version_is_less('1.18.0', self.bolt_version(host))
      '--targets'
    else
      '--nodes'
    end
  end

  def run_puppet_access_login(user:, password: '~!@#$%^*-/ aZ', lifetime: '5y')
    peconf_password = get_unwrapped_pe_conf_value("console_admin_password")
    password = peconf_password if peconf_password != nil && peconf_password != ""
    on(master, puppet('access', 'login', '--username', user, '--lifetime', lifetime), stdin: password)
  end

  #Setup ssh access between task runner and nodes
  #@param [Host] Task runner
  #@param [Array<Host> Nodes on which to run the task
  #
  #TODO: Implement on windows
  def setup_ssh_access(task_runner, nodes)
    task_runner_ssh_dir = '/root/.ssh'
    task_runner_rsa_pub = "#{task_runner_ssh_dir}/id_rsa.pub"
    on task_runner, "ssh-keygen -f #{task_runner_ssh_dir}/id_rsa -t rsa -N ''"
    public_key = on(task_runner, "cat #{task_runner_rsa_pub}").stdout

    nodes.each do |node|
        case node.platform
        when /solaris-10/
            ssh_dir_path = '/.ssh/'
        when /osx-10\.1(2|3|4)/
            ssh_dir_path = '/var/root/.ssh/'
        else
            ssh_dir_path = '/root/.ssh'
        end
        rsa_pub_path = "#{ssh_dir_path}/id_rsa.pub"
        create_remote_file(node, "#{rsa_pub_path}", public_key)
        on(node, "cat #{rsa_pub_path} >> #{ssh_dir_path}/authorized_keys")
    end
  end

  def run_task(task_name:, params: nil, password: DEFAULT_PASSWORD, host: nil, format: 'human')
    output = if pe_install?
               host = master.hostname if host.nil?
               run_puppet_task(task_name: task_name, params: params, host: host, format: format)
             else
               host = '127.0.0.1' if host.nil?
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
                    host: '127.0.0.1', format: 'human', module_path: nil)
    if fact_on(default, 'os.family') == 'windows'
      module_path ||= 'C:/ProgramData/PuppetLabs/code/modules'

      if version_is_less('0.15.0', self.bolt_version)
        check = '--no-ssl'
      else
        check = '--insecure'
      end
    else
      module_path ||='/etc/puppetlabs/code/modules'

      if version_is_less('0.15.0', self.bolt_version)
        check = '--no-host-key-check'
      else
        check = '--insecure'
      end
    end

    bolt_full_cli = "#{bolt_path} task run #{task_name} #{check} -m #{module_path} " \
                    "#{target_flag} #{host} --password #{password}"
    bolt_full_cli << " --format #{format}" if format != 'human'
    bolt_full_cli << if params.class == Hash
                       " --params '#{params.to_json}'"
                     else
                       " #{params}"
                     end
    # windows is special
    if fact_on(default, 'os.family') == 'windows'
      bolt_full_cli << ' --transport winrm --user Administrator'
    end
    puts "BOLT_CLI: #{bolt_full_cli}" if ENV['BEAKER_debug']
    on(default, bolt_full_cli, acceptable_exit_codes: [0, 1, 2]).stdout
  end

  def run_puppet_task(task_name:, params: nil, host: '127.0.0.1', format: 'human')
    args = ['task', 'run', task_name, target_flag(master), host]
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
    "Job completed. #{success_hosts}/#{total_hosts} targets succeeded|Ran on #{total_hosts} target"
  end
end

include Beaker::TaskHelper
