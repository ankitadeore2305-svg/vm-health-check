# vm-health-check

Run the health check on an Ubuntu VM:

```bash
chmod +x vm-health-check.sh
./vm-health-check.sh
```

The script checks CPU and memory usage, plus usage of the root filesystem. The VM is `Healthy` only when all three are below 60%; otherwise it is `Not healthy`. Pass `explain` to print the measurements and which limit(s) caused the result:

```bash
./vm-health-check.sh explain
```