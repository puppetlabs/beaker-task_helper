require 'beaker'

module Beaker
  module TaskHelper
    # Default Constants used by beaker-task_helper
    module Defaults
      include Beaker::DSL

      DEFAULT_PASSWORD = if defined?(default)
                           if [:hypervisor] == 'vagrant'
                             'puppet'
                           elsif default[:hypervisor] == 'vcloud' || default[:hypervisor] == 'vmpooler'
                             'Qu@lity!'
                           else
                             'root'
                           end
                         end

      BOLT_VERSION = '0.7.0'.freeze

      DEFAULT_MODULE_PATH = if defined?(defaut)
                              if default['platform'] =~ %r{windows}
                                'C:/ProgramData/PuppetLabs/code/modules'
                              else
                                '/etc/puppetlabs/code/modules'
                              end
                            end
    end
  end
end

include Beaker::TaskHelper::Defaults
