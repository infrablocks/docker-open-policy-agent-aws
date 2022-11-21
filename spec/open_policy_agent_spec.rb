# frozen_string_literal: true

require 'spec_helper'

describe 'open policy agent' do
  image = 'open-policy-agent-aws:latest'
  extra = {
    'Entrypoint' => '/bin/sh'
  }

  before(:all) do
    set :backend, :docker
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  describe 'command' do
    after(:all, &:reset_docker_backend)

    it 'includes the opa command' do
      expect(command('opa --version').stdout)
        .to(match(/x\.y\.0/))
    end
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end
end
