require 'spec_helper'

describe 'chef-splunk::server should create custom dir "/var/lib/splunk_db"' do
  describe file('/var/lib/splunk_db') do
    it { should be_directory }
    it { should be_owned_by 'splunk' }
    it { should be_grouped_into 'splunk' }
  end
end

describe 'chef-splunk::server should set SPLUNK_DB to "/var/lib/splunk_db"' do
  describe file('/opt/splunk/etc/splunk-launch.conf') do
    it { should contain('SPLUNK_DB = /var/lib/splunk_db') }
  end
end

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
