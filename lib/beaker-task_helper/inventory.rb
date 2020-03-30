require 'beaker'

module Beaker
  module TaskHelper
    module Inventory
      def target_key
        if version_is_less('1.18.0', BOLT_VERSION)
          'targets'
        else
          'nodes'
        end
      end

      # This attempts to make a bolt inventory hash from beakers hosts
      # roles should be targetable by bolt as groups
      def hosts_to_inventory
        groups = []

        def add_node(node, group_name, groups)
          if group_name =~ %r{\A[a-z0-9_]+\Z}
            group = groups.find { |g| g['name'] == group_name }
            unless group
              group = { 'name' => group_name, target_key => [] }
              groups << group
            end
            group[target_key] << node
          else
            puts "invalid group name #{group_name} skipping"
          end
        end

        nodes = hosts.map do |host|
          # Make sure nodes with IPs have unique target names
          node_name = host[:ip] ? "#{host[:ip]}?n=#{host.hostname}" : host.hostname

          if host[:platform] =~ %r{windows}
            config = { 'transport' => 'winrm',
                       'winrm' => { 'ssl' => false,
                                    'user' => host[:user],
                                    'password' => ENV['BEAKER_password'] } }
          else
            config = { 'transport' => 'ssh',
                       'ssh' => { 'host-key-check' => false } }
            %i[password user port].each do |k|
              config['ssh'][k.to_s] = host[:ssh][k] if host[:ssh][k]
            end

            case host[:hypervisor]
            when 'docker'
              nil
            when 'vagrant'
              key = nil
              keys = host.connection.instance_variable_get(:@ssh).options[:keys]
              key = keys.first if keys
              config['ssh']['private-key'] = key if key
            when 'vmpooler', 'abs'
              key = nil
              keys = host[:ssh][:keys]
              key = keys.first if keys
              config['ssh']['private-key'] = key if key
            else
              raise "Can't generate inventory for platform #{host[:platform]} hypervisor #{host[:hypervisor]}"
            end
          end

          # make alias groups for each role
          host[:roles].each do |role|
            add_node(node_name, role, groups)
          end

          {
            'name' => node_name,
            'config' => config
          }
        end

        { target_key => nodes,
          'groups' => groups,
          'config' => {
            'ssh' => {
              'host-key-check' => false
            }
          } }
      end
    end
  end
end
