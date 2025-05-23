# 一加13、ACE 5 Pro本地编译<br>
## 使用方法<br>
* `git clone https://github.com/sucigmail/build_oneplus_sm8750.git`<br>
* ``cd build_oneplus_sm8750``<br>
* ``chmod +x Build_Kernel.sh``<br>
* ``./Build_Kernel.sh``<br>
## Windows推荐使用WSL运行-这里提供WSL转移到其他盘（E）避免文件占用C盘<br>
### WSL2迁移至其他目录<br>
#### (1) 管理员身份运行PowerShell，执行：<br>
``wsl -l -v``<br>
#### (2) 停止正在运行的wsl<br>

``wsl --shutdown``<br>

#### (3) 将需要迁移的Linux，进行导出<br>

``wsl --export Ubuntu-20.04 E:/ubuntu.tar``<br>

#### (4) 导出完成之后，将原有的Linux卸载<br>

``wsl --unregister Ubuntu-20.04``<br>

#### (5) 将导出的文件放到需要保存的地方，进行导入即可<br>

``wsl --import Ubuntu-20.04 E:\ubuntu\ E:\ubuntu.tar --version 2``<br>

#### (6) 设置默认用户<br>
``ubuntu2004.exe config --default-user <username>  ``<br>
#### 如果是ubuntu20.04 就是ubuntu2004.exe<br>
