#!/bin/bash
set -e

echo "[1/25] Cloning ros2_raspberry_pi_5..."
cd ~
if [ -d ros2_raspberry_pi_5 ]; then
  echo "ros2_raspberry_pi_5 already exists, skip git clone"
else
  git clone https://github.com/ozandmrz/ros2_raspberry_pi_5
fi
cd ros2_raspberry_pi_5
chmod +x ros2_humble_install.sh

echo "[2/25] Installing ROS 2 Humble (may take a long time)..."
./ros2_humble_install.sh
grep -qxF "source ~/ros2_humble/install/local_setup.bash" ~/.bashrc || echo "source ~/ros2_humble/install/local_setup.bash" >> ~/.bashrc
source ~/.bashrc

cd ~

echo "[3/25] Adding ROS 2 apt key and repo..."
sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-keys F42ED6FBAB17C654
echo "deb http://repo.ros2.org/ubuntu/main bookworm main" | sudo tee /etc/apt/sources.list.d/ros2.list
sudo apt update

echo "[4/25] Installing additional ROS tools..."
sudo apt install -y python3-pip python3-setuptools python3-colour python3-rosdep python3-ament-package

echo "[5/25] Fixing potential dpkg problems with rospkg..." # MAY BE ERROR
sudo dpkg --remove --force-all python3-catkin-pkg
sudo dpkg --remove --force-remove-reinstreq python3-rospkg python3-rosdistro
sudo apt -y --fix-broken install
sudo apt install -y python3-catkin-pkg-modules python3-rospkg-modules python3-rosdistro-modules

echo "[6/25] Installing OpenCV and python3 bindings..."
sudo apt install -y libopencv-dev python3-opencv

echo "[7/25] Installing gcc-11 and setting as default..."
sudo apt-get update
sudo apt-get install -y gcc-11 g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 60 --slave /usr/bin/g++ g++ /usr/bin/g++-11
#echo "Choose auto mode to set /usr/bin/gcc-11"
#sudo update-alternatives --config gcc
# Choose auto mode (0) to set /usr/bin/gcc-11
gcc --version

echo "[8/25] Installing build tools and core libraries..."
sudo apt-get update
sudo apt-get install -y build-essential cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev

echo "[9/25] Installing image/video libraries..."
sudo apt-get install -y libtbb12 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-dev libxvidcore-dev libx264-dev

echo "[10/25] Installing math/boost/SuiteSparse dependencies..."
sudo apt-get install -y libatlas-base-dev gfortran python3-dev libeigen3-dev libboost-all-dev libsuitesparse-dev

echo "[11/25] Installing more OpenCV-related dependencies (legacy Python2)..."
sudo apt-get install -y libopencv-dev libglew-dev cmake libpython3-dev libboost-python-dev libepoxy-dev

echo "[12/25] Cloning and preparing ROS image packages..."

mkdir -p ~/my_ros2_workspace/src
cd ~/my_ros2_workspace/src
if [ -d image_common ]; then
  echo "image_common already exists, skip git clone"
else
  git clone https://github.com/ros-perception/image_common.git
fi
cd image_common
git checkout humble
cd ~/my_ros2_workspace/src
if [ -d vision_opencv ]; then
  echo "vision_opencv already exists, skip git clone"
else
  git clone https://github.com/ros-perception/vision_opencv.git
fi
cd vision_opencv/cv_bridge
git checkout humble

echo "[13/25] Building my_ros2_workspace..."
cd ~/my_ros2_workspace
colcon build --symlink-install
source ~/my_ros2_workspace/install/local_setup.sh
sudo apt update
sudo apt install -y python3-rosdep
rosdep install --from-paths src --ignore-src -r -y
sudo apt -y remove libcv-bridge-dev
sudo apt autoremove

echo "[14/25] Cloning and building Pangolin..."
cd ~
if [ -d Pangolin ]; then
  echo "Pangolin already exists, skip git clone"
else
  git clone https://github.com/stevenlovegrove/Pangolin.git
fi
cd Pangolin
mkdir -p build
cd build
cmake ..
make -j4
sudo make install

echo "[15/25] Cloning ORB_SLAM3..."
cd ~
ORB_SLAM3_CLONE=false
if [ -d ORB_SLAM3 ]; then
  echo "ORB_SLAM3 already exists, skip git clone"
else
  git clone https://github.com/ozandmrz/ORB_SLAM3
  ORB_SLAM3_CLONE=true
fi
cd ~/ORB_SLAM3

echo "[16/25] Building DBoW2..."
# Build Thirdparty/DBoW2:
cd Thirdparty/DBoW2
if [ "$ORB_SLAM3_CLONE" = true ]; then
  rm -rf build
fi
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j2

echo "[17/25] Building g2o..."
# Build Thirdparty/g2o:
cd ../../g2o
if [ "$ORB_SLAM3_CLONE" = true ]; then
  rm -rf build
fi
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j2

echo "[18/25] Building Sophus..."
# Build Thirdparty/Sophus:
cd ../../Sophus
if [ "$ORB_SLAM3_CLONE" = true ]; then
  rm -rf build
fi
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j2
sudo make install

echo "[19/25] Extracting ORBvoc.txt..."
# Uncompress the vocabulary:
cd ../../../Vocabulary
tar -xf ORBvoc.txt.tar.gz

echo "[20/25] Building ORB_SLAM3..."
# Build ORB_SLAM3:
cd ~/ORB_SLAM3
ln -sf ../Thirdparty include/Thirdparty
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4

echo "[21/25] Cloning orbslam3_pose..."
mkdir -p ~/ros2_pose/src
cd ~/ros2_pose/src
if [ -d orb_slam3_ros2_mono_publisher ]; then
  echo "orb_slam3_ros2_mono_publisher already exists, skip git clone"
else
  git clone https://github.com/ozandmrz/orb_slam3_ros2_mono_publisher.git
fi
echo "[22/25] Installing dependencies for orbslam3_pose..."
cd ~/ros2_pose
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install

echo "[23/25] Updating .bashrc with environment variables..."
grep -qxF "source ~/ros2_pose/install/setup.bash" ~/.bashrc || echo "source ~/ros2_pose/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
grep -qxF 'export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:~/ORB_SLAM3:~/ORB_SLAM3/Thirdparty/Sophus' ~/.bashrc || echo 'export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:~/ORB_SLAM3:~/ORB_SLAM3/Thirdparty/Sophus' >> ~/.bashrc
grep -qxF "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/ORB_SLAM3/lib" ~/.bashrc || echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/ORB_SLAM3/lib" >> ~/.bashrc
grep -qxF "source ~/ros2_humble/install/local_setup.bash" ~/.bashrc || echo "source ~/ros2_humble/install/local_setup.bash" >> ~/.bashrc
grep -qxF "export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:~/ORB_SLAM3/Thirdparty/DBoW2:~/ORB_SLAM3/Thirdparty/g2o" ~/.bashrc || echo "export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:~/ORB_SLAM3/Thirdparty/DBoW2:~/ORB_SLAM3/Thirdparty/g2o" >> ~/.bashrc
grep -qxF "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/ORB_SLAM3/Thirdparty/DBoW2/lib:~/ORB_SLAM3/Thirdparty/g2o/lib" ~/.bashrc || echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/ORB_SLAM3/Thirdparty/DBoW2/lib:~/ORB_SLAM3/Thirdparty/g2o/lib" >> ~/.bashrc
grep -qxF "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib" ~/.bashrc || echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib" >> ~/.bashrc
source ~/.bashrc

echo "[24/25] Cloning and building image_publisher..."
mkdir -p ~/image_publisher/src
cd ~/image_publisher/src
if [ -d ros2_image_publisher ]; then
  echo "ros2_image_publisher already exists, skip git clone"
else
  git clone https://github.com/ozandmrz/ros2_image_publisher.git
fi
cd ~/image_publisher
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
grep -qxF "source ~/image_publisher/install/setup.bash" ~/.bashrc || echo "source ~/image_publisher/install/setup.bash" >> ~/.bashrc
source ~/.bashrc

echo "[25/25] Installing X11 packages for display..."
sudo apt update
sudo apt install -y x11-apps x11-xserver-utils xserver-xorg-video-fbdev

echo "[✅ Done] System is now ready to run ORB_SLAM3 with ROS 2."
echo "[ℹ] To apply changes, run:"
echo "    source ~/.bashrc"
