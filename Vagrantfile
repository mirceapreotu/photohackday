# -*- mode: ruby -*-
# vi: set ft=ruby :

configuration = { private_ip: '172.16.16.120' }

Vagrant.configure("2") do |config|

  ### GLOBAL CONFIGS ###
  config.ssh.private_key_path    = '~/.ssh/vagrant'
  config.hostmanager.enabled     = true
  config.hostmanager.manage_host = true
  config.vm.synced_folder ".", "/vagrant", disabled: false

  config.vm.define "photohackday" do |s|
    s.vm.box      = "hashicorp/precise32"
    s.vm.hostname = "photohackday.local"

    s.vm.provider :virtualbox do |virtualbox|
      virtualbox.customize ["modifyvm", :id, "--memory", "1024"]
    end

    s.vm.network "private_network", ip: configuration[:private_ip]
    s.vm.provision :hostmanager

    s.vm.provision :shell, inline: <<SCRIPT
      if [ -f "/var/vagrant_provision" ];
        then exit 0
      fi

      sudo apt-get update

      # redis install
      sudo apt-get install redis-server
      sudo sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
      sudo redis-server /etc/redis/redis.conf

      # install bundler, gems, etc

      sudo touch /var/vagrant_provision
SCRIPT
  end
end