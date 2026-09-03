function decompress --description "Expand or extract bundled & compressed files"
  for file in $argv
    if test -f $file
      gum log -sl info "Extracting $file"
      switch $file
        case *.tar
          tar -xvf $file
        case *.tar.bz2 *.tbz2
          tar -jxvf $file
        case *.tar.gz *.tgz
          tar -zxvf $file
        case *.bz2
          bunzip2 $file
        case *.gz
          gunzip $file
        case *.rar
          unrar x $file
        case *.zip *.ZIP
          unzip $file
        case '*.*'
          gum log -sl warn "Extension not recognized, cannot extract $file"
      end
    else
      gum log -sl error "$file is not a valid file"
    end
  end
end
