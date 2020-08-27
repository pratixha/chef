#
# Copyright:: Copyright (c) Chef Software Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative "../resource"
require_relative "../dist"
class Chef
  class Resource
    class ChefClientLaunchd < Chef::Resource
      unified_mode true

      provides :chef_client_launchd

      description "Use the **chef_client_launchd** resource to configure the #{Chef::Dist::PRODUCT} to run on a schedule."
      introduced "16.5"
      examples <<~DOC
        **Set the #{Chef::Dist::PRODUCT} to run on a schedule**:

        ```ruby
        chef_client_launchd 'Setup the #{Chef::Dist::PRODUCT} to run every 30 minutes' do
          interval 30
          action :enable
        end
        ```

        **Disable the #{Chef::Dist::PRODUCT} running on a schedule**:

        ```ruby
        chef_client_launchd 'Prevent the #{Chef::Dist::PRODUCT} from running on a schedule' do
          action :disable
        end
        ```
      DOC

      property :user, String,
        description: "The name of the user that #{Chef::Dist::PRODUCT} runs as.",
        default: "root"

      property :working_directory, String,
        description: "The working directory to run the #{Chef::Dist::PRODUCT} from.",
        default: "/var/root"

      property :interval, [Integer, String],
        description: "Time in minutes between #{Chef::Dist::PRODUCT} executions.",
        coerce: proc { |x| Integer(x) },
        callbacks: { "should be a positive number" => proc { |v| v > 0 } },
        default: 30

      property :splay, [Integer, String],
        default: 300,
        coerce: proc { |x| Integer(x) },
        callbacks: { "should be a positive number" => proc { |v| v > 0 } },
        description: "A random number of seconds between 0 and X to add to interval so that all #{Chef::Dist::CLIENT} commands don't execute at the same time."

      property :accept_chef_license, [true, false],
        description: "Accept the Chef Online Master License and Services Agreement. See <https://www.chef.io/online-master-agreement/>",
        default: false

      property :config_directory, String,
        description: "The path of the config directory.",
        default: Chef::Dist::CONF_DIR

      property :log_directory, String,
        description: "The path of the directory to create the log file in.",
        default: "/Library/Logs/Chef"

      property :log_file_name, String,
        description: "The name of the log file to use.",
        default: "client.log"

      property :chef_binary_path, String,
        description: "The path to the #{Chef::Dist::CLIENT} binary.",
        default: "/opt/#{Chef::Dist::DIR_SUFFIX}/bin/#{Chef::Dist::CLIENT}"

      property :daemon_options, Array,
        description: "An array of options to pass to the #{Chef::Dist::CLIENT} command.",
        default: lazy { [] }

      property :environment, Hash,
        description: "A Hash containing additional arbitrary environment variables under which the launchd daemon will be run in the form of `({'ENV_VARIABLE' => 'VALUE'})`.",
        default: lazy { {} }

      property :nice, [Integer, String],
        description: "The process priority to run the #{Chef::Dist::CLIENT} process at. A value of -20 is the highest priority and 19 is the lowest priority.",
        coerce: proc { |x| Integer(x) },
        callbacks: { "should be an Integer between -20 and 19" => proc { |v| v >= -20 && v <= 19 } }

      property :low_priority_io, [true, false],
        description: "Run the #{Chef::Dist::CLIENT} process with low priority disk IO",
        default: true

      action :enable do
        unless ::Dir.exist?(new_resource.log_directory)
          directory new_resource.log_directory do
            owner new_resource.user
            mode "0750"
            recursive true
          end
        end

        launchd "com.chef.chef-client" do
          username new_resource.user
          working_directory new_resource.working_directory
          start_interval new_resource.interval * 60
          program_arguments client_command
          environment_variables new_resource.environment unless new_resource.environment.empty?
          nice new_resource.nice
          low_priority_io true
          action :enable
        end
      end

      action :disable do
        service "chef-client" do
          service_name "com.chef.chef-client"
          action :disable
        end
      end

      action_class do
        #
        # Generate a uniformly distributed unique number to sleep from 0 to the splay time
        #
        # @param [Integer] splay The number of seconds to splay
        #
        # @return [Integer]
        #
        def splay_sleep_time(splay)
          seed = node["shard_seed"] || Digest::MD5.hexdigest(node.name).to_s.hex
          random = Random.new(seed.to_i)
          random.rand(splay)
        end

        #
        # random sleep time + chef-client + daemon option properties + license acceptance
        #
        # @return [Array]
        #
        def client_command
          cmd = ["/bin/sleep",
                 "#{splay_sleep_time(new_resource.splay)};",
                 new_resource.chef_binary_path] +
            new_resource.daemon_options +
            ["-c",
            ::File.join(new_resource.config_directory, "client.rb"),
            "-L",
            ::File.join(new_resource.log_directory, new_resource.log_file_name),
            ]
          cmd.append("--chef-license", "accept") if new_resource.accept_chef_license
          cmd
        end
      end
    end
  end
end