function compdir --description 'Compare 2 directories'
    diff -rq "$1" "$2"
end
