function gpg-init --description 'Init your gpg key'
    user_name=$(gum input --prompt "Enter your name : ")
    user_email=$(gum input --prompt "Enter your email : ")

    ## Create the master key ( cert ) & sub key [SEA]
    gpg2 --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: cert
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: sign
Name-Real: ${user_name}
Name-Email: ${user_email}
Expire-Date: 0
EOF

    # Retrieve the key fingerprint
    FPR=$(gpg --list-options show-only-fpr-mbox --list-secret-keys | awk '{print $1}')

    # Add an encryption sub-key
    gpg --batch --passphrase '' --quick-add-key $FPR rsa4096 encrypt 0
    # Add an authentication sub-key
    gpg --batch --passphrase '' --quick-add-key $FPR rsa4096 auth 0
end