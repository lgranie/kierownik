function gpg-sign-pub --description 'Extract gpg sign pub key'
    gpg_key_id=$(gpg2 --list-secret-keys --keyid-format LONG | grep ssb | sed -E 's/.*\/([0-9A-Z]*) .*\[.*S.*\]/\1/')
    
    gpg_pubkey=$(gpg --armor --export ${gpg_key_id})
    echo "Your gpg pub key is"
    echo ${gpg_pubkey}

    gum confim "Copy to clipboard?" && echo ${gpg_pubkey} | wl-copy
end