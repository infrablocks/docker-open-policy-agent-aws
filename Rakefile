# frozen_string_literal: true

require 'rake_docker'
require 'rake_circle_ci'
require 'rake_github'
require 'rake_ssh'
require 'rake_gpg'
require 'rake_terraform'
require 'securerandom'
require 'yaml'
require 'git'
require 'os'
require 'pathname'
require 'semantic'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

require_relative 'lib/version'

Docker.options = {
  read_timeout: 300
}

def repo
  Git.open(Pathname.new('.'))
end

def latest_tag
  repo.tags.map do |tag|
    Semantic::Version.new(tag.name)
  end.max
end

def tmpdir
  base = (ENV['TMPDIR'] || '/tmp')
  OS.osx? ? "/private#{base}" : base
end

task default: %i[
  test:code:fix
  test:integration
]

namespace :encryption do
  namespace :directory do
    desc 'Ensure CI secrets directory exists.'
    task :ensure do
      FileUtils.mkdir_p('config/secrets/ci')
    end
  end

  namespace :passphrase do
    desc 'Generate encryption passphrase used by CI.'
    task generate: ['directory:ensure'] do
      File.write('config/secrets/ci/encryption.passphrase',
                 SecureRandom.base64(36))
    end
  end
end

namespace :keys do
  namespace :deploy do
    RakeSSH.define_key_tasks(
      path: 'config/secrets/ci/',
      comment: 'maintainers@infrablocks.io'
    )
  end

  namespace :gpg do
    RakeGPG.define_generate_key_task(
      output_directory: 'config/secrets/ci',
      name_prefix: 'gpg',
      owner_name: 'InfraBlocks Maintainers',
      owner_email: 'maintainers@infrablocks.io',
      owner_comment: 'docker-open-policy-agent-aws CI Key'
    )
  end
end

namespace :secrets do
  desc 'Regenerate all generatable secrets.'
  task regenerate: %w[
    encryption:passphrase:generate
    keys:deploy:generate
    keys:gpg:generate
  ]
end

RakeCircleCI.define_project_tasks(
  namespace: :circle_ci,
  project_slug: 'github/infrablocks/docker-open-policy-agent-aws'
) do |t|
  circle_ci_config =
    YAML.load_file('config/secrets/circle_ci/config.yaml')

  t.api_token = circle_ci_config['circle_ci_api_token']
  t.environment_variables = {
    ENCRYPTION_PASSPHRASE:
        File.read('config/secrets/ci/encryption.passphrase')
            .chomp
  }
  t.checkout_keys = []
  t.ssh_keys = [
    {
      hostname: 'github.com',
      private_key: File.read('config/secrets/ci/ssh.private')
    }
  ]
end

RakeGithub.define_repository_tasks(
  namespace: :github,
  repository: 'infrablocks/docker-open-policy-agent-aws'
) do |t, args|
  github_config =
    YAML.load_file('config/secrets/github/config.yaml')

  t.access_token = github_config['github_personal_access_token']
  t.deploy_keys = [
    {
      title: 'CircleCI',
      public_key: File.read('config/secrets/ci/ssh.public')
    }
  ]
  t.branch_name = args.branch_name
  t.commit_message = args.commit_message
end

namespace :pipeline do
  desc 'Prepare CircleCI Pipeline'
  task prepare: %i[
    circle_ci:project:follow
    circle_ci:env_vars:ensure
    circle_ci:checkout_keys:ensure
    circle_ci:ssh_keys:ensure
    github:deploy_keys:ensure
  ]
end

namespace :image do
  RakeDocker.define_image_tasks(
    image_name: 'open-policy-agent-aws-lambda'
  ) do |t|
    t.work_directory = 'build/images'

    t.copy_spec = %w[
      src/open-policy-agent-aws-lambda/Dockerfile
      src/open-policy-agent-aws-lambda/start.sh
      src/open-policy-agent-aws-lambda/bootstrap.sh
    ]

    t.repository_name = 'open-policy-agent-aws-lambda'
    t.repository_url = 'infrablocks/open-policy-agent-aws-lambda'

    t.credentials = YAML.load_file(
      'config/secrets/dockerhub/credentials.yaml'
    )

    t.platform = 'linux/amd64'

    t.tags = [latest_tag.to_s, 'latest']
  end
end

RuboCop::RakeTask.new

namespace :test do
  namespace :code do
    desc 'Run all checks on the test code'
    task check: [:rubocop]

    desc 'Attempt to automatically fix issues with the test code'
    task fix: [:'rubocop:autocorrect_all']
  end

  RSpec::Core::RakeTask.new(
    integration: %w[image:build]
  ) do |t|
    t.rspec_opts = %w[--format documentation]
  end
end

namespace :version do
  desc 'Bump version for specified type (pre, major, minor, patch)'
  task :bump, [:type] do |_, args|
    next_tag = latest_tag.send("#{args.type}!")
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end

  desc 'Release gem'
  task :release do
    next_tag = latest_tag.release!
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end
end
