require_relative '../spec_helper'

describe 'chef-splunk::setup_datastore_dir' do
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

  context 'custom datastore dir' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show datastore-dir -auth '#{secrets['splunk__default']['auth']}' | grep ': /datadrive'").and_return(false)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/opt/splunk/etc/.initialize_datastore').and_return(false)
      chef_run_init.node.set['splunk']['server']['edit_datastore_dir'] = true
      chef_run_init.node.set['splunk']['server']['datastore_dir'] = '/datadrive'
    end

    it 'updates the datastore dir' do
      expect(chef_run).to run_execute('update-datastore-dir').with(
        'command' => "/opt/splunk/bin/splunk set datastore-dir /datadrive -auth '#{secrets['splunk__default']['auth']}'"
      )
    end
  end
end