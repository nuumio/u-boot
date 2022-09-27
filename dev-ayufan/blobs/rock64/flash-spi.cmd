setenv blink_power 'led power off; sleep 0.1; led power on'
setenv blink_standby 'led standby off; sleep 0.1; led standby on'

# first read existing loader
run blink_power
sf probe

# or load rksd_loader.img and write it to 8000 offset of spi
# or fail badly

if size ${devtype} ${devnum}:${distro_bootpart} rksd_loader.img; then
  load ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} rksd_loader.img

  # erase flash
  run blink_power blink_power
  sf erase 8000 3f8000

  # write flash
  run blink_power blink_power blink_power
  sf write ${kernel_addr_r} 8000 ${filesize}

  # blink forever
  while true; do run blink_power; sleep 1; done
else
  # blink forever
  echo "missing rksd_loader.img"
  while true; do run blink_standby; sleep 1; done
fi
