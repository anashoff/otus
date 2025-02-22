Vagrant.configure(2) do |config|

    N = 2
    (1..N).each do |i|
      config.vm.define "mysql#{i}" do |node|
        node.vm.box = "bento/ubuntu-22.04"
        node.vm.synced_folder ".", "/vagrant", disabled: true
        node.vm.hostname = "mysql#{i}"
        node.vm.network "private_network", ip:"10.0.26.10#{i}"
        node.vm.provider "virtualbox" do |vb|
          vb.memory = "1024"
          vb.name = "mysql#{i}"
          vb.cpus = 2
        end
      end
    end
 
end