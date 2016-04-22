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

    it 'does not starts the splunk service' do
      expect(chef_run).to_not start_service('splunk')
    end
  end

  context 'splunk server' do
    before(:each) do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/opt/splunk/ftr').and_return(true)
      chef_run_init.node.set['splunk']['is_server'] = true
    end
    
    it 'enables the service at boot and accepts the license' do
      expect(chef_run).to run_execute('/opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes')
    end

    it 'does not start the splunk service' do
      expect(chef_run).to_not start_service('splunk')
    end
  end
end