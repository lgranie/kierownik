#!/usr/bin/env fish

function compress --description 'Create tar.gz archive from file or directory'
    tar -czvf "$1.tar.gz" "$1"
end

function decompress --description 'Extract tar.gz archive'
    tar -xzvf "$1"
end
