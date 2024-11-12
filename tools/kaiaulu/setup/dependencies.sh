#! /bin/sh

# Configure git (required for git calls from kaiaulu)
git config --global user.email "kaiaulu@example.com"
git config --global user.name "Kaiaulu"

# Install perceval for git log parsing
cd /home/saner
curl -O https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh
bash Anaconda3-2024.10-1-Linux-x86_64.sh -b -p /home/saner/anaconda3
rm Anaconda3-2024*
eval "$(/home/saner/anaconda3/bin/conda shell.bash hook)"
conda init
echo ". /home/saner/anaconda3/etc/profile.d/conda.sh" >> /home/saner/.bashrc
source /home/saner/.bashrc
conda config --set auto_activate_base False

conda create --name kaiaulu python=3.11 pip -y
conda activate kaiaulu
pip install perceval==0.12.24
Rscript /home/saner/tools/kaiaulu/setup/packages.R
cd /home/saner/tools/kaiaulu
Rscript /home/saner/tools/kaiaulu/setup/install.R

# Install ctags for git blame analysis
cd /home/saner
wget https://github.com/universal-ctags/ctags-nightly-build/releases/download/2023.08.22%2Bd104ee5b17c9d11b030ad5c4ee345cbfee8826e6/uctags-2023.08.22-linux-x86_64.tar.xz
tar -xf uctags-2023.08.22-linux-x86_64.tar.xz
mkdir -p /home/saner/ctags-kaiaulu/install
mv uctags-2023.08.22-linux-x86_64/bin/ /home/saner/ctags-kaiaulu/install/
rm -rf uctags-2023.08.22-linux-x8rm uctags-2023.08.22-linux-x86_64.tar.xz
