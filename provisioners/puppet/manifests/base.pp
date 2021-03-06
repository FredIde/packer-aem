File {
  backup => false,
}

class base (
  $tmp_dir,
  $python_package,
  $python_pip_package,
  $python_cheetah_package,
  $rhn_register = false,
  $disable_selinux = true,
  $install_aws_cli = true,
  $install_cloudwatchlogs = true,
  $install_aws_agents = true,
  $aws_agents_install_url = 'https://d1wk0tztpsntt1.cloudfront.net/linux/latest/install'
){

  stage { 'test':
    require => Stage['main']
  }

  class { 'timezone': }

  if $::osfamily == 'redhat' {

    if $rhn_register {
      class { 'rhn_register':
        use_classic => false,
      }
    }

    if $disable_selinux {
      # issue with selinux stopping aem:dispatcher to start. https://github.com/bstopp/puppet-aem/issues/73
      class { 'selinux':
        mode => 'disabled',
      }
    }
  }

  file_line { 'sudo_rule_keep_proxy_vairables':
    path => '/etc/sudoers',
    line => 'Defaults    env_keep += "ftp_proxy http_proxy https_proxy no_proxy"',
  }

  package { 'unzip':
    ensure => installed,
  }

  package { [ $python_package, $python_pip_package, $python_cheetah_package ]:
    ensure => latest,
  }

  # needed for running various aem-tools and aws-tools scripts
  # TODO: this is a candidate to be moved to a package requirement
  # when those Python scripts are turned into a proper CLI app
  package { [ 'boto3', 'requests', 'retrying', 'sh' ]:
    ensure   => latest,
    provider => 'pip',
  }

  package { 'jq':
    ensure => installed,
  }

  if $install_aws_cli {

    package { 'awscli':
      ensure   => latest,
      provider => 'pip',
    }

  }

  if $install_cloudwatchlogs {

    class { '::cloudwatchlogs': }

  }

  # if $install_aws_agents {
  #
  #   #TODO: create a puppet module for installing the aws agent. push it up to puppet forge.
  #   file { "${tmp_dir}/awsagent":
  #     ensure => directory,
  #     mode   => '0775',
  #     owner  => $packer_user,
  #     group  => $packer_group
  #   } ->
  #   wget::fetch { $aws_agents_install_url:
  #     destination => "${tmp_dir}/awsagent/install",
  #     timeout     => 0,
  #     verbose     => false,
  #   } ->
  #   file { "${tmp_dir}/awsagent/install":
  #     ensure => file,
  #     mode   => '0755',
  #     owner  => $packer_user,
  #     group  => $packer_group
  #   } ->
  #   exec { "${tmp_dir}/awsagent/install":
  #     path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin/bash',
  #   }
  #
  # }


  # needed for running Serverspec, used for testing baked AMIs and provisioned EC instances
  package { 'gcc':
    ensure  => 'installed',
  }
  package { 'ruby-devel':
    ensure  => 'installed',
  }
  package { 'zlib-devel':
    ensure  => 'installed',
  }
  package { 'rake':
    ensure   => '12.0.0',
    provider => 'gem',
  }
  package { 'rspec':
    ensure   => '3.5.0',
    provider => 'gem',
  }
  package { 'serverspec':
    ensure   => '2.38.0',
    provider => 'gem',
  }


  class { 'serverspec':
    stage             => 'test',
    component         => 'base',
    staging_directory => "${tmp_dir}/packer-puppet-masterless-base",
    tries             => 5,
    try_sleep         => 3,
  }

}

include base
