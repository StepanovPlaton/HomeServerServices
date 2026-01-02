sudo apt update
sudo apt install linux-cpupower

sudo cpupower frequency-set -g ondemand

echo "===== CPU FREQUENCY INFO ====="
cpupower frequency-info
