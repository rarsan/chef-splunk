require_relative '../spec_helper'

describe 'chef-splunk::setup_ssl' do
  let(:certs) do
    {
      'splunk_certificates' => {
        'id' => 'splunk_certificates',
        'data' => {
          'self-signed.example.com.key' => '-----BEGIN RSA PRIVATE KEY-----',
          'self-signed.example.com.crt' => '-----BEGIN CERTIFICATE-----',
        },
      },
    }
  end

  context 'ssl is enabled' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new do |node, server|
        node.normal['splunk']['ssl_options']['enable_ssl'] = true
        node.normal['splunk']['is_server'] = true
        node.normal['dev_mode'] = true
        # Populate mock certs data into Chef server
        server.create_data_bag('vault', certs)
      end.converge(described_recipe)
    end

    it 'includes chef-vault' do # ~FC005
      expect(chef_run).to include_recipe('chef-vault::default')
    end

    it 'enables SSL in the web.conf file' do
      expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('enableSplunkWebSSL = true')
    end

    it 'writes web.conf with http port 443' do
      expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('httpport = 443')
    end

    context 'using custom certificates (default)' do
      it 'writes the SSL key from the chef-vault data bag item' do
        expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.key').with_content(/BEGIN RSA PRIVATE KEY/)
      end

      it 'writes the SSL certificate from the chef-vault data bag item' do
        expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.crt').with_content(/BEGIN CERTIFICATE/)
      end
    end

    context 'using default certificates' do
      before(:each) do
        chef_run.node.normal['splunk']['ssl_options']['use_default_certs'] = true
        chef_run.converge(described_recipe)
      end

      it 'enables SSL in the web.conf file' do
        expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('enableSplunkWebSSL = true')
      end

      it 'does not point to custom certificates, instead using default certificates' do
        expect(chef_run).to_not render_file('/opt/splunk/etc/system/local/web.conf').with_content('privKeyPath')
        expect(chef_run).to_not render_file('/opt/splunk/etc/system/local/web.conf').with_content('caCertPath')
      end

      it 'does not write a custom SSL key' do
        expect(chef_run).to_not render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.key')
      end

      it 'does not write a custom SSL certificate' do
        expect(chef_run).to_not render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.crt')
      end
    end

    context 'alternative webui port' do
      before(:each) do
        chef_run.node.normal['splunk']['web_port'] = '7777'
        chef_run.converge(described_recipe)
      end

      it 'writes web.conf with a non-default port for https' do
        expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('httpport = 7777')
      end
    end
  end
end