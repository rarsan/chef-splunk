require_relative '../spec_helper'

describe 'chef-splunk::server' do
  let(:secrets) do
    {
      'splunk__default' => {
        'id' => 'splunk__default',
        'auth' => 'admin:notarealpassword',
        'secret' => 'notarealsecret'
      }
    }
  end

  let(:chef_run_init) do
    ChefSpec::ServerRunner.new do |node, server|
      node.set['dev_mode'] = true
      node.set['splunk']['is_server'] = true
      # Populate mock vault data bag to the server
      server.create_data_bag('vault', secrets)
    end
  end

  let(:chef_run) do
    chef_run_init.converge(described_recipe)
  end

  before(:each) do
    allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_return(true)
    stub_command("/opt/splunk/bin/splunk enable listen 9997 -auth '#{secrets['splunk__default']['auth']}'").and_return(true)
  end

  context 'default settings' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth '#{secrets['splunk__default']['auth']}' | grep ': 8089'").and_return('Splunkd port: 8089')
    end

    it 'does not update splunkd management port' do
      expect(chef_run).to_not run_execute('update-splunk-mgmt-port')
    end

    it 'does not link to any license master' do
      expect(chef_run).to_not run_execute('link-to-license-master')
    end

    it 'enables receiver port' do
      expect(chef_run).to run_execute('enable-splunk-receiver-port').with(
        'command' => "/opt/splunk/bin/splunk enable listen 9997 -auth '#{secrets['splunk__default']['auth']}'"
      )
    end
  end

  context 'custom management port' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth '#{secrets['splunk__default']['auth']}' | grep ': 9089'").and_return(false)
      chef_run_init.node.set['splunk']['mgmt_port'] = '9089'
    end

    it 'updates splunkd management port' do
      expect(chef_run).to run_execute('update-splunk-mgmt-port').with(
        'command' => "/opt/splunk/bin/splunk set splunkd-port 9089 -auth '#{secrets['splunk__default']['auth']}'"
      )
    end

    it 'notifies the splunk service to restart when changing management port' do
      execution = chef_run.execute('update-splunk-mgmt-port')
      expect(execution).to notify('service[splunk]').to(:restart)
    end

    it 'enables receiver port' do
      expect(chef_run).to run_execute('enable-splunk-receiver-port').with(
        'command' => "/opt/splunk/bin/splunk enable listen 9997 -auth '#{secrets['splunk__default']['auth']}'"
      )
    end
  end

  context 'custom datastore dir' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth '#{secrets['splunk__default']['auth']}' | grep ': 8089'").and_return('Splunkd port: 8089')
      stub_command("/opt/splunk/bin/splunk show datastore-dir -auth '#{secrets['splunk__default']['auth']}' | grep ': /datadrive'").and_return(false)
      chef_run_init.node.set['splunk']['server']['edit_datastore_dir'] = true
      chef_run_init.node.set['splunk']['server']['datastore_dir'] = '/datadrive'
    end

    it 'updates the datastore dir' do
      expect(chef_run).to run_execute('update-datastore-dir').with(
        'command' => "/opt/splunk/bin/splunk set datastore-dir /datadrive -auth '#{secrets['splunk__default']['auth']}'"
      )
    end

    it 'notifies the splunk service to restart when updating datastore dir' do
      execution = chef_run.execute('update-datastore-dir')
      expect(execution).to notify('service[splunk]').to(:restart)
    end
  end

  context 'local slave license' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth '#{secrets['splunk__default']['auth']}' | grep ': 8089'").and_return('Splunkd port: 8089')
      chef_run_init.node.set['splunk']['server']['license'] = 'slave'
      # Publish mock license master node to the server
      license_master_node = stub_node(platform: 'ubuntu', version: '12.04') do |node|
        node.automatic['fqdn'] = 'license-master.example.com'
        node.automatic['ipaddress'] = '192.168.0.10'
        node.set['dev_mode'] = true
        node.set['splunk']['is_server'] = true
        node.set['splunk']['mgmt_port'] = '8089'
        node.set['splunk']['server']['license'] = 'master'
      end
      chef_run_init.create_node(license_master_node)
    end

    it 'links to license master' do
      expect(chef_run).to run_execute('link-to-license-master').with(
        'command' => "/opt/splunk/bin/splunk edit licenser-localslave -master_uri 'https://192.168.0.10:8089' -auth '#{secrets['splunk__default']['auth']}'"
      )
    end
  end

  context 'clustering enabled' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show splunkd-port -auth '#{secrets['splunk__default']['auth']}' | grep ': 8089'").and_return('Splunkd port: 8089')
      chef_run_init.node.set['splunk']['clustering']['enabled'] = true
    end

    context 'peer node' do
      before(:each) do
        chef_run_init.node.set['splunk']['clustering']['mode'] = 'slave'
      end

      it 'enables receiver port' do
        expect(chef_run).to run_execute('enable-splunk-receiver-port').with(
          'command' => "/opt/splunk/bin/splunk enable listen 9997 -auth '#{secrets['splunk__default']['auth']}'"
        )
      end
    end

    context 'non indexer node (master)' do
      before(:each) do
        chef_run_init.node.set['splunk']['clustering']['mode'] = 'master'
      end

      it 'does not enable receiver port' do
        expect(chef_run).to_not run_execute('enable-splunk-receiver-port')
      end
    end

    context 'non indexer node (search head)' do
      before(:each) do
        chef_run_init.node.set['splunk']['clustering']['mode'] = 'searchhead'
      end

      it 'does not enable receiver port' do
        expect(chef_run).to_not run_execute('enable-splunk-receiver-port')
      end
    end
  end
end
