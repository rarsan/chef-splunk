require_relative '../spec_helper'

describe 'chef-splunk::service' do
  let(:chef_run_init) do
    ChefSpec::ServerRunner.new do |node|
      node.set['splunk']['accept_license'] = true
    end
  end

  let(:chef_run) do
    chef_run_init.converge(described_recipe)
  end

  context 'splunk client' do
    it 'enables the service at boot and accepts the license' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/opt/splunkforwarder/ftr').and_return(true)
      expect(chef_run).to run_execute('/opt/splunkforwarder/bin/splunk enable boot-start --accept-license --answer-yes')
    end

    it 'does not set the datastore dir' do
      expect(chef_run).to_not run_execute('splunk_server_edit_datastore_dir')
    end 

    it 'starts the splunk service' do
      expect(chef_run).to start_service('splunk')
    end
  end

  context 'splunk server with custom datastore dir' do
    before(:each) do
      stub_command("/opt/splunk/bin/splunk show datastore-dir | grep ': /datadrive'").and_return(false) 
      stub_command("/opt/splunk/bin/splunk set datastore-dir /datadrive").and_return("Datastore path changed to '/datadrive'")
      chef_run_init.node.set['splunk']['is_server'] = true
      chef_run_init.node.set['splunk']['server']['edit_datastore_dir'] = true
      chef_run_init.node.set['splunk']['server']['datastore_dir'] = '/datadrive'
    end
    
    it 'enables the service at boot and accepts the license' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/opt/splunk/ftr').and_return(true)
      expect(chef_run).to run_execute('/opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes')
    end

    it 'sets the datastore dir' do
      expect(chef_run).to run_execute('splunk_server_edit_datastore_dir').with(
        'command' => '/opt/splunk/bin/splunk set datastore-dir /datadrive'
      )
    end 

    it 'starts the splunk service' do
      expect(chef_run).to start_service('splunk')
    end
  end
end