#
# Cookbook Name:: splunk
# Recipe:: server
#
# Author: Joshua Timberman <joshua@chef.io>
# Copyright (c) 2014, Chef Software, Inc <legal@chef.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
node.default['splunk']['is_server'] = true
include_recipe 'chef-splunk::user'
include_recipe 'chef-splunk::install_server'
include_recipe 'chef-splunk::service'
include_recipe 'chef-splunk::setup_auth'
include_recipe 'chef-splunk::initialize_datastore'

# ensure that the splunk service resource is available without cloning
# the resource (CHEF-3694). this is so the later notification works,
# especially when using chefspec to run this cookbook's specs.
begin
  resources('service[splunk]')
rescue Chef::Exceptions::ResourceNotFound
  service 'splunk'
end

# We can rely on loading the chef_vault_item here, as `setup_auth`
# above would have failed if there were another issue.
splunk_auth_info = chef_vault_item(:vault, "splunk_#{node.chef_environment}")['auth']

execute 'update-splunk-mgmt-port' do
  command "#{splunk_cmd} set splunkd-port #{node['splunk']['mgmt_port']} -auth '#{splunk_auth_info}'"
  user splunk_user
  group splunk_user
  not_if "#{splunk_cmd} show splunkd-port -auth '#{splunk_auth_info}' | grep ': #{node['splunk']['mgmt_port']}'", :user => splunk_user
  notifies :restart, 'service[splunk]'
end

if node['splunk']['server']['license'] == 'slave'
  license_master = search( # ~FC003
    :node, "\
    splunk_server_license:master AND \
    chef_environment:#{node.chef_environment}"
  ).first

  if license_master
    execute 'link-to-license-master' do
      command "#{splunk_cmd} edit licenser-localslave -master_uri 'https://#{license_master['ipaddress'] || license_master['fqdn']}:#{license_master['splunk']['mgmt_port']}' -auth '#{splunk_auth_info}'"
      user splunk_user
      group splunk_user
      retries 3
      ignore_failure true
      notifies :restart, 'service[splunk]'
    end
  end
end

if !node['splunk']['clustering']['enabled'] || node['splunk']['clustering']['mode'] == 'slave'
  execute 'enable-splunk-receiver-port' do
    command "#{splunk_cmd} enable listen #{node['splunk']['receiver_port']} -auth '#{splunk_auth_info}'"
    user splunk_user
    group splunk_user
    not_if do
      # TCPSocket will return a file descriptor if it can open the
      # connection, and raise Errno::ECONNREFUSED if it can't. We rescue
      # that exception and return false so not_if works proper-like.
      begin
        ::TCPSocket.new(node['ipaddress'], node['splunk']['receiver_port'])
      rescue Errno::ECONNREFUSED
        false
      end
    end
  end
end

if node['splunk']['ssl_options']['enable_ssl']
  include_recipe 'chef-splunk::setup_ssl'
end

if node['splunk']['clustering']['enabled']
  include_recipe 'chef-splunk::setup_clustering'
end

service 'splunk' do
  action :start
end
