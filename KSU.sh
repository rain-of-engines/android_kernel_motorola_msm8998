# Update KSU

echo "Update KSU"
rm -rf KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
echo ""
