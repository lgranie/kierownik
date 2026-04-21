function register-u2f-key --description 'Register u2f/fido key'
    pamu2fcfg --pin-verification | run0 bash -c 'tee /etc/u2f_mappings'
end