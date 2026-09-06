# flyline: interactive bash only
case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac
if [ -n "${BASH_VERSION:-}" ]; then
  enable flyline 2>/dev/null || enable -f /usr/lib64/libflyline.so flyline
fi
