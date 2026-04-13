function ssh-pub --description 'Extract ssh pub key with email'
    subkey_keygrip=$(gpg --list-keys --with-keygrip | awk '$0 ~ /A/ {getline; print $3}')
    
    if not test -f .gnupg/sshcontrol
        echo ${subkey_keygrip} >> ~/.gnupg/sshcontrol
    end

    ssh_pubkey=$(gpg --export-ssh-key $1)
    echo "Your ssh pub key is :"
    echo ${ssh_pubkey}

    gum confim "Copy to clipboard?" && echo ${ssh_pubkey} | wl-copy
end