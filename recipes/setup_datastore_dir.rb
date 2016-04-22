#
# Cookbook Name:: splunk
# Recipe:: setup_datastore_dir
#
# Author: Roy Arsan <rarsan@splunk.com>
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

# ensure that the splunk service resource is available without cloning
# the resource (CHEF-3694). this is so the later notification works,
# especially when using chefspec to run this cookbook's specs.
begin
  resources('service[splunk]')
rescue Chef::Exceptions::ResourceNotFound
  service 'splunk'
end

include_recipe 'chef-vault'

passwords = chef_vault_item('vault', "splunk_#{node.chef_environment}")
splunk_auth_info = passwords['auth']

if node['splunk']['server']['edit_datastore_dir']
  # If using custom SPLUNK_DB path, chown to appropriate user
  directory node['splunk']['server']['datastore_dir'] do
    owner splunk_user
    group splunk_user
    mode 00711
  end

  execute 'update-datastore-dir' do
    command "#{splunk_cmd} set datastore-dir #{node['splunk']['server']['datastore_dir']} -auth '#{splunk_auth_info}'"
    user splunk_user
    group splunk_user
    not_if { ::File.exist?("#{splunk_dir}/etc/.initialize_datastore") }
    not_if "#{splunk_cmd} show datastore-dir -auth '#{splunk_auth_info}' | grep ': #{node['splunk']['server']['datastore_dir']}'", :user => splunk_user
  end
end

file "#{splunk_dir}/etc/.initialize_datastore" do
  content 'true\n'
  owner node['splunk']['user']['username']
  group node['splunk']['user']['username']
  mode 00600
end