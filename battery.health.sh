#!/bin/bash
#shellcheck disable=SC2207

# Reports Mac portable battery health, cycle count, max capacity, and hardware/firmware revisions as a Jamf-style `<result>` extension attribute. Exits early on non-portable Macs.

if ! /usr/sbin/system_profiler -json SPHardwareDataType | /usr/bin/jq -r '.SPHardwareDataType[].machine_name' | /usr/bin/grep -q -i 'book'
then
    echo "<result>no</result>"; exit
fi

IFS=$'\n'
pwrdata=($(/usr/libexec/PlistBuddy \
    -c "print 0:_items:0:sppower_battery_health_info:sppower_battery_health" \
    -c "print 0:_items:0:sppower_battery_health_info:sppower_battery_cycle_count" \
    -c "print 0:_items:0:sppower_battery_health_info:sppower_battery_health_maximum_capacity" \
    -c "print 0:_items:0:sppower_battery_charge_info:sppower_battery_max_capacity" \
    -c "print 0:_items:0:sppower_battery_model_info:sppower_battery_manufacturer" \
    -c "print 0:_items:0:sppower_battery_model_info:sppower_battery_firmware_version" \
    -c "print 0:_items:0:sppower_battery_model_info:sppower_battery_hardware_revision" \
    -c "print 0:_items:0:sppower_battery_model_info:sppower_battery_cell_revision" \
    /dev/stdin <<< "$(/usr/sbin/system_profiler -xml SPPowerDataType)" 2> /dev/null))

result(){
    echo "Health = ${pwrdata[0]}"
    echo "Cycle Count = ${pwrdata[1]}"

    if [[ "${pwrdata[2]}" == *'%'* ]]
    then
        echo "Max Capacity = ${pwrdata[2]}"
    else
        echo "Max Capacity = ${pwrdata[2]} mAh"
    fi

    if [ "$(/usr/sbin/sysctl -in hw.optional.arm64)" = 1 ] && /usr/sbin/sysctl -n machdep.cpu.brand_string | /usr/bin/grep -q 'Apple' && /usr/bin/uname -v | /usr/bin/grep -q 'ARM64'
    then
        i=5 # Apple Silicon
    else
        i=6 # Intel
        echo "Manufacturer = ${pwrdata[i-3]}"
    fi

    echo "Firmware Version = ${pwrdata[i-2]}"
    echo "Hardware Revision = ${pwrdata[i-1]}"
    echo "Cell Revision = ${pwrdata[i]}"
}

echo "<result>$(result)</result>"
