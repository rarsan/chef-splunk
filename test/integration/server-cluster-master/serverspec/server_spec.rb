require 'spec_helper'

describe 'chef-splunk::server should run as "splunk" user' do
  describe command('ps aux | grep "splunkd -p" | head -1 | awk \'{print $1}\'') do
    its(:stdout) { should match(/splunk/) }
  end
end

describe 'chef-splunk::server should listen on web_port 8443' do
  describe port(8443) do
    it { should be_listening.with('tcp') }
  end
end

describe 'server config should be configured per node attributes' do
  describe file('/opt/splunk/etc/system/local/server.conf') do
    it { should be_file }
    its(:content) { should match(/\[clustering\]/) }
    its(:content) { should match(/^mode = master$/) }
    its(:content) { should match(/^replication_factor = 5$/) }
    its(:content) { should match(/^search_factor = 3$/) }
  end
end
