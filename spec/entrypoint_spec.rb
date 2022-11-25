# frozen_string_literal: true
#
# require 'spec_helper'
# require 'net/http'
# require 'uri'
#
# describe 'entrypoint' do
#   image = 'open-policy-agent-aws-lambda:latest'
#   extra = {
#     'Entrypoint' => '/bin/sh',
#     'ExposedPorts' => { '8080/tcp' => {} },
#     'PortBindings' => {
#       '8080/tcp' => [
#         { 'HostPort' => '9000' }
#       ]
#     }
#   }
#
#   before(:all) do
#     set :backend, :docker
#     set :docker_image, image
#     set :docker_container_create_options, extra
#   end
#
#   describe 'by default' do
#     before(:all) do
#       execute_lambda_entrypoint(
#         started_indicator: 'starting RIE and request handler'
#       )
#     end
#
#     after(:all, &:reset_docker_backend)
#
#     it 'runs opa' do
#       sleep 20
#       http = Net::HTTP.new('localhost', 9000)
#       response = http.request(
#         Net::HTTP::Post.new(
#           '/2015-03-31/functions/function/invocations', {}
#         )
#       )
#       puts response
#       log = command('cat /tmp/lambda-entrypoint.log').stdout
#       puts log
#       sleep 60
#       expect(process('/opt/opa/bin/opa')).to(be_running)
#     end
#   end
#
#   def reset_docker_backend
#     Specinfra::Backend::Docker.instance.send :cleanup_container
#     Specinfra::Backend::Docker.clear
#   end
#
#   def execute_command(command_string)
#     command = command(command_string)
#     exit_status = command.exit_status
#     unless exit_status == 0
#       raise "\"#{command_string}\" failed with exit code: #{exit_status}"
#     end
#
#     command
#   end
#
#   def wait_for_contents(file, content)
#     Octopoller.poll(timeout: 60) do
#       docker_entrypoint_log = command("cat #{file}").stdout
#       docker_entrypoint_log =~ /#{content}/ ? docker_entrypoint_log : :re_poll
#     end
#   rescue Octopoller::TimeoutError => e
#     puts command("cat #{file}").stdout
#     raise e
#   end
#
#   def execute_lambda_entrypoint(opts)
#     logfile_path = '/tmp/lambda-entrypoint.log'
#     start_command = "/var/runtime/start.sh > #{logfile_path} 2>&1 &"
#     started_indicator = opts[:started_indicator]
#
#     execute_command(start_command)
#     wait_for_contents(logfile_path, started_indicator)
#   end
# end
