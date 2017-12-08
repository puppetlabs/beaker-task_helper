require 'beaker'

module Beaker::TaskHelper::Defaults # rubocop:disable Style/ClassAndModuleChildren
  include Beaker::DSL


  DEFAULT_PASSWORD = if defined?(default)
                       if [:hypervisor] == 'vagrant'
                         'puppet'
                       elsif default[:hypervisor] == 'vcloud' || default[:hypervisor] == 'vmpooler'
                         'Qu@lity!'
                       else
                         'root'
                       end
                     else
                       nil
                     end

  BOLT_VERSION = '0.7.0'.freeze

  DEFAULT_MODULE_PATH = if defined?(defaut)
                          if default['platform'] =~ /windows/
                            'C:/ProgramData/PuppetLabs/code/modules'
                          else
                            '/etc/puppetlabs/code/modules'
                          end
                        else
                          nil
                        end
end

include Beaker::TaskHelper::Defaults
