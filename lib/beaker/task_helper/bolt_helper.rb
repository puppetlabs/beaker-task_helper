require 'beaker'
require 'beaker/task_helper/defaults'

# Beaker task Helper
module Beaker::TaskHelper::BoltHelper
  include Beaker::DSL

  # Installs bolt on a host or an Array of hsts
  #
  # @param [Host, Array<Host>] hosts The hosts to install bolt on
  # @param [String] version The version of bolt to install, used when source is a gem server
  # @param [String] source where to retrieve gem from, gem source or path to locally built gem on coordinator
  #
  # @example Install specific version from gem server
  # install_bolt_on(bolt, '0.11.0', 'https://rubygems.mysweetgemserver.net/')
  #
  # @example Install gem from local source on SUT
  # install_bolt_on(bolt, nil, '/home/ztr/repos/bolt/pkg/bolt-0.10.0.gem')
  def install_bolt_on(hosts, version = BOLT_VERSION, source = nil)
    Array(hosts).each do |host|
      install_ruby(host)
      options = if File.file?(source)
                  verify_and_copy_gem(host, source)
                elsif source
                  "--version #{version} --source #{source}"
                else
                  "--version #{version}"
                end
      command = "gem install bolt #{options}"
      result = nil
      case host['platform']
        when /windows/
          execute_powershell_script_on(host, command)
          result = on(host, powershell('bolt --help'))
        else
          on(host, command)
          result = bolt_on(host, 'bolt --help')
      end
      message = "Bolt was not installed properly on #{host}"
      raise message unless result.stdout =~ /Usage: bolt <subcommand>/
    end
  end

  # runs a bolt task from the default host
  #
  # @param params [Hash] options used by bolt task
  # @option params [String] :task_name
  # @option params [Hash, String] :params argument to '--params'
  # @option params [String] :password argument to '--password'
  # @option params [String] :host argument to '--nodes'
  # @option params [String] :format argument to '--format'
  # @option params [String] :module_path  argument to '-m'
  #
  # @example Run the exec task
  # run_bolt_task(task_name: 'exec', params: {command: 'ls -la'}, format: 'json')
  def run_bolt_task(task_name:, params: nil, password: DEFAULT_PASSWORD, host: 'localhost', format: 'human', module_path: DEFAULT_MODULE_PATH) # rubocop:disable Metrics/LineLength, Lint/UnusedMethodArgument
    raise 'No default host specified' unless defined?(default)
    bolt_full_cli = "bolt task run #{task_name} --insecure -m #{module_path} --nodes #{host} --password #{password}, --format #{format}" # rubocop:disable Metrics/LineLength
    bolt_full_cli << if params.is_a?(Hash)
                       " --params '#{params.to_json}'"
                     else
                       " #{params}"
                     end
    # windows is special
    if default['platform'] =~ /windows/
      bolt_full_cli << ' --transport winrm --user Administrator'
    end
    puts "BOLT_CLI: #{bolt_full_cli}" if ENV['BEAKER_debug']
    bolt_on(default, bolt_full_cli, acceptable_exit_codes: [0, 1]).stdout
  end

  # choose the correct shell for bolt
  #
  # @param host [Host] host to execute bolt on
  # @param command [String] bolt CLI string
  # @param opts [Hash] opts hash to pass to the on command
  #
  # @example
  # bolt_on(bolt_host, 'bolt command run 'ls -la' --nodes ssh://foo.bar.net')
  def bolt_on(host, command, opts = {})
    if host['platform'] =~ /windows/
      execute_powershell_script_on(host, command, opts)
    elsif host['platform'] =~ /osx/
      env = 'source /etc/profile  ~/.bash_profile ~/.bash_login ~/.profile &&'
      on(host, env + ' ' + command)
    else
      on(host, command, opts)
    end
  end

  # Installs ruby on a SUT
  #
  # @private
  #
  # @param host [Host] the host to install ruby on
  #
  # @example install ruby
  # install_ruby(bolt_host)
  def install_ruby(host)
    result = nil
    case host['platform']
      when /windows/
        # use chocolatey to install latest ruby
        execute_powershell_script_on(host, <<-PS)
Set-ExecutionPolicy AllSigned
$choco_install_uri = 'https://chocolatey.org/install.ps1'
iex ((New-Object System.Net.WebClient).DownloadString($choco_install_uri))
        PS
        # HACK: to add chocolatey path to cygwin: this path should at least be
        # instrospected from the STDOUT of the installer.
        host.add_env_var('PATH', '/cygdrive/c/ProgramData/chocolatey/bin:PATH')
        on(host, powershell('choco install ruby -y'))
        # HACK: to add ruby path to cygwin
        host.add_env_var('PATH', '/cygdrive/c/tools/ruby24/bin:PATH')
        result = on(host, powershell('ruby --version'))
      when /debian|ubuntu/
        # install system ruby packages
        install_package(host, 'ruby')
        install_package(host, 'ruby-dev')
        result = on(host, 'ruby --version')
      when /el-|centos|fedora/
        # install system ruby packages
        install_package(host, 'ruby')
        install_package(host, 'ruby-devel')
        result = on(host, 'ruby --version')
      when /osx/
        # ruby dev tools should be already installed
        result = on(host, 'ruby --version')
      else
        raise "#{host['platform']} not currently a supported bolt controller"
    end
    message = "The required ruby could not be installed on #{host}"
    raise message unless result.stdout =~ /ruby 2/
  end

  # Matches a given path as a gem and copies file to host
  #
  # @private
  #
  # @param host [Host] the host to copy the gem to
  # @param source [String] the path to a .gem file
  #
  # @example
  # verify_and_copy_gem(bolt_host, '/home/ztr/repos/bolt/pkg/bolt-0.10.0.gem')
  def verify_and_copy_gem(host, source)
    message = 'When passing source a local file it must match /\.gem$/'
    raise ArgumentError.new(message) unless source =~ /\.gem$/
    system_temp_path = host.system_temp_path
    scp_to(host, source, system_temp_path)
    if host['platform'] =~ /windows/
      gem_name = source.split('\\').last
      [host.system_temp_path, gem_name].join('\\')
    else
      gem_name = source.split('/').last
      File.join(system_temp_path, gem_name)
    end
  end
end

include Beaker::TaskHelper::BoltHelper
