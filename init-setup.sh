#! /bin/bash
sudo apt-get install git zsh curl wget unzip fontconfig
echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo "Installing starship..."
sh -c "$(curl -fsSL https://starship.rs/install.sh)"
echo "[-] Download fonts [-]"
echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip"
wget -N https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip
unzip FiraCode.zip -d ~/.fonts
fc-cache -fv
echo "Done! Fira code installed"
echo "Installing zsh-autosuggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
echo "Adding zsh-autosuggestions to zsh plugins..." 
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
echo "eval \"\$(starship init zsh)\"" >> ~/.zshrc
source ~/.zshrc
echo "Downloading starship config file..."
wget -N https://raw.githubusercontent.com/radu-pythia/init-setup/main/starship.toml
mv starship.toml ~/.config/starship.toml
echo "Hopefully done!"
