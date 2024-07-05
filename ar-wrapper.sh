#!/bin/sh

#wrapper that turns
#ar -L/usr/local/opt/llvm/lib/c++ -Wl,-rpath,/usr/local/opt/llvm/lib/c++ -bundle -undefined dynamic_lookup -all_load -o /var/folders/ps/cqv_3ytx5nn59k5q3k17th500000gn/T/luarocks_build-LuaFileSystem-1.8.0-1-2725638/lfs.so src/lfs.o
#into
#ar rcu lfs.a src/lfs.o
#by just finding the object files and replacing the -o argument with the archive file

#find the object files, they will always have the .o or .obj extension
objects=""
for arg in "$@"; do
    if [ "${arg##*.}" = "o" ] || [ "${arg##*.}" = "obj" ]; then
        objects="$objects $arg"
    fi
done

#find the archive file
archive=""
for arg in "$@"; do
    if [ "${arg##*.}" = "so" ] || [ "${arg##*.}" = "dll" ] || [ "${arg##*.}" = "dylib" ] || [ "${arg##*.}" = "a" ]; then
        archive="$arg"
    fi
done

# replace the extension with .a
# archive="${archive%.so}.a"
# we need ti keep the .so so that luarocks can copy it

#run the ar command
echo "$ ar rcu $archive $objects"
ar rcu $archive $objects
