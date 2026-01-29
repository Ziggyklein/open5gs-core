

sudo apt update
sudo apt install -y git net-tools build-essential cmake \
                   libfftw3-dev libmbedtls-dev \
                   libboost-program-options-dev \
                   libconfig++-dev libsctp-dev \
                   libyaml-cpp-dev libgtest-dev \
                   libzmq3-dev
sudo apt install -y iproute2 iptables
sudo apt-get install cmake make gcc g++ pkg-config libmbedtls-dev libsctp-dev libgtest-dev
sudo apt install -y libnuma-dev meson ninja-build python3-pip python3-pyelftools
sudo apt install -y ccache
sudo apt install -y libbackward-cpp-dev

sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli \
                   containerd.io docker-buildx-plugin \
                   docker-compose-plugin

sudo usermod -aG docker $(whoami)
newgrp docker

cd ~
git clone https://github.com/srsRAN/srsRAN_Project.git

cd srsRAN_Project
mkdir build
cd build
cmake -DDU_SPLIT_TYPE=SPLIT_7_2  ../
make -j $(nproc)
make test -j $(nproc)

sudo make install

cd ~/srsRAN_Project/docker
docker compose up --build 5gc -d

docker ps
docker logs -f open5gs_5gc
