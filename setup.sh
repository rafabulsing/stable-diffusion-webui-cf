# disable the restart dialogue and install several packages
echo 'Installing dependencies...'
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt-get update
sudo apt install wget git python3 python3-venv build-essential net-tools awscli nginx apache2-utils -y

# install syncthing
echo 'Installing Syncthing...'
sudo apt install curl apt-transport-https -y
curl -s https://syncthing.net/release-key.txt | sudo apt-key add -
echo "deb https://apt.syncthing.net/ syncthing release" | sudo tee /etc/apt/sources.list.d/syncthing.list
sudo apt update
sudo apt install syncthing -y
sudo cp stable-diffusion-webui-cf/synthing /etc/systemd/system/syncthing@.service
sudo systemctl daemon-reload
sudo systemctl start syncthing@$USER
sudo systemctl enable syncthing@$USER

# install CUDA (from https://developer.nvidia.com/cuda-downloads)
echo 'Installing CUDA...'
wget https://developer.download.nvidia.com/compute/cuda/12.0.0/local_installers/cuda_12.0.0_525.60.13_linux.run
sudo sh cuda_12.0.0_525.60.13_linux.run --silent

# configure NGINX
echo 'Configuring NGINX...'
sudo ufw allow 'Nginx HTTP'
sudo cp stable-diffusion-webui-cf/nginx.conf /etc/nginx/nginx.conf

# create credentials
sudo htpasswd -c -i /etc/nginx/.htpasswd $2 <<< $3
sudo nginx -s reload

# install git-lfs
echo 'Installing git-lfs...'
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
sudo apt-get install git-lfs
sudo -u ubuntu git lfs install --skip-smudge

# clone SD repo
echo 'Cloning Stable Diffusion Web UI repository...'
sudo -u ubuntu git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui

# download the SD model v2.1 and move it to the SD model directory
echo 'Downloading SD model...'
sudo -u ubuntu git clone --depth 1 https://huggingface.co/stabilityai/stable-diffusion-2-1-base
cd stable-diffusion-2-1-base/
sudo -u ubuntu git lfs pull --include "v2-1_512-ema-pruned.ckpt"
sudo -u ubuntu git lfs install --force
cd ..
mv stable-diffusion-2-1-base/v2-1_512-ema-pruned.ckpt stable-diffusion-webui/models/Stable-diffusion/
rm -rf stable-diffusion-2-1-base/

# download the corresponding config file and move it also to the model directory (make sure the name matches the model name)
echo 'Downloading model configuration file...'
wget https://raw.githubusercontent.com/Stability-AI/stablediffusion/main/configs/stable-diffusion/v2-inference.yaml
cp v2-inference.yaml stable-diffusion-webui/models/Stable-diffusion/v2-1_512-ema-pruned.yaml

# change ownership of the web UI so that a regular user can start the server
sudo chown -R ubuntu:ubuntu stable-diffusion-webui/

# start the server as user 'ubuntu'
echo 'Starting web UI...'
sudo -u ubuntu nohup bash stable-diffusion-webui/webui.sh --listen
