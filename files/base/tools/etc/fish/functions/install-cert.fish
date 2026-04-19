function install-cert -a site --description 'Install certificate from site'
    set server_name (string split ":" $site -f1)
    echo quit | openssl s_client -showcerts -servername $server_name -connect $site 2>/dev/null | sed -ne '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > /tmp/$server_name
    sudo mv /tmp/$server_name /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust extract
end
