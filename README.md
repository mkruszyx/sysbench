# sysbench (Windows)

## Building and Installing From Source

### Build Requirements

#### CMake 3.26
```shell
   wget -q https://cmake.org/files/v3.26/cmake-3.26.6-windows-x86_64.msi
   cmake-3.26.6-windows-x86_64.msi /passive
```

### Build
As of sysbench 1.1.0, support for building with CMake was added on all supported platforms.
### Using CMake + without SQL support + create cpack package
```shell
   cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DWITH_LIBMARIADB=OFF -DWITH_MYSQL=OFF .
   cmake --build . -j --config Release --target package
```

### Install
Unpack zip package and execute bat/ps1 script
```shell
   if not exist "%CD%\sysbench_extract" mkdir "%CD%\sysbench_extract" && tar -xf "sysbench-1.1.0-win64.zip" -C "%CD%\sysbench_extract" && for /f "delims=" %F in ('dir /b /s "%CD%\sysbench_extract\install-sysbench.bat"') do call "%F"
```