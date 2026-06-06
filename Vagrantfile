Vagrant.configure("2") do |config|
  # Windows/Linux : ubuntu/jammy64
  # Mac Apple Silicon: bento/ubuntu-22.04
  config.vm.box = "ubuntu/jammy64"
  # config.vm.box = "bento/ubuntu-22.04"

  nodes = [
    ["database",  "192.168.56.21", "VM-DB-Travel"],
    ["backend",   "192.168.56.20", "VM-Backend-Travel"],
    ["frontend",  "192.168.56.22", "VM-Frontend-Travel"]
  ]

  nodes.each do |name, ip, vname|
    config.vm.define name do |machine|
      machine.vm.hostname = name
      machine.vm.network "private_network", ip: ip
      machine.vm.provider "virtualbox" do |vb|
        vb.name   = vname
        vb.memory = "1024"
        vb.cpus   = 1
      end
      machine.vm.provision "shell", inline: <<-SHELL
        echo "=== Installing Ansible on #{name} ==="
        sudo apt-get update -y
        sudo apt-get install -y ansible
        echo "=== Running Playbook for #{name} ==="
        sudo ansible-playbook /vagrant/playbook.yml \
          -c local \
          -e "target_node=#{name}"
      SHELL
    end
  end
end
