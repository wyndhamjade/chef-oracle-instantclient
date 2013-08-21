#
# Cookbook Name:: oracle-instantclient
# Recipe:: default
#
# Copyright (C) 2013 Wyndham Jade LLC
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

arch = case node['kernel']['machine']
       when 'x86_64' then '.x64'
       else ''
       end

include_recipe 'apt'

package 'unzip'
package 'libaio1'

install_dir = node['oracle_instantclient']['install_dir']
base_dir = "#{install_dir}/#{node['oracle_instantclient']['product_subdir']}"

directory node['oracle_instantclient']['install_dir'] do
  owner 'root'
  group 'root'
  mode 0755
end

node['oracle_instantclient']['components'].select { |k,v| v }.keys.each do |component|
  filename = "instantclient-#{component}-linux#{arch}-#{node['oracle_instantclient']['version']}.zip"
  local_file = "#{Chef::Config['file_cache_path']}/#{filename}"
  source_url = "#{node['oracle_instantclient']['download_base_url']}/#{filename}"

  remote_file local_file do
    source source_url
    owner 'root'
    group 'root'
    mode 0644
    action :create_if_missing
    notifies :run, "bash[unzip_instant_client_#{component}]", :immediately
  end

  bash "unzip_instant_client_#{component}" do
    code <<-EOF
      /usr/bin/unzip -o "#{local_file}" -d "#{install_dir}"
    EOF
    action :nothing
    notifies :run, 'bash[symlink_oracle_libs]', :immediately if [ 'basic', 'basiclite' ].include? component
  end
end

bash 'symlink_oracle_libs' do
  cwd base_dir
  code <<-EOF
    ln -s libocci.so.11.1 libocci.so
    ln -s libclntsh.so.11.1 libclntsh.so
  EOF
  action :nothing
  notifies :run, 'bash[update_ld.so]', :delayed
end

file '/etc/ld.so.conf.d/oracle-instantclient.conf' do
  owner 'root'
  group 'root'
  mode 0644
  content <<EOF
# This file is generated by Chef.
# Oracle Instant Client library path.
#{base_dir}
EOF
  notifies :run, 'bash[update_ld.so]', :delayed
end

bash 'update_ld.so' do
  command 'ldconfig'
  action :nothing
end
