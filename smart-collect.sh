#!/bin/bash
# smart-collect.sh — Samlar SMART-data från alla diskar och returnerar JSON.
# Körs av Cockpit-pluginet via cockpit.spawn()
# Kräver: smartmontools (smartctl)

set -euo pipefail

# Hitta alla block devices (diskar, ej partitioner)
DEVICES=$(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1}')

# Hitta NVMe-enheter
NVME_DEVICES=$(ls /dev/nvme[0-9]n[0-9] 2>/dev/null || true)

ALL_DEVICES="$DEVICES $NVME_DEVICES"
ALL_DEVICES=$(echo "$ALL_DEVICES" | tr ' ' '\n' | sort -u | grep -v '^$')

python3 -c "
import subprocess, json, sys, re

devices = '''$ALL_DEVICES'''.strip().split('\n')
devices = [d.strip() for d in devices if d.strip()]

results = []

for dev in devices:
    disk = {'device': dev, 'healthy': None, 'attributes': [], 'info': {}, 'error': None}

    # --- smartctl -i (info) ---
    try:
        r = subprocess.run(['sudo', 'smartctl', '-i', dev], capture_output=True, text=True, timeout=10)
        for line in r.stdout.splitlines():
            if ':' in line:
                key, _, val = line.partition(':')
                key = key.strip()
                val = val.strip()
                if key in ('Model Family', 'Device Model', 'Serial Number',
                           'Firmware Version', 'User Capacity', 'Rotation Rate',
                           'Model Number', 'Total NVMe Capacity', 'Form Factor'):
                    disk['info'][key] = val
    except Exception as e:
        disk['error'] = str(e)

    # --- smartctl -H (health) ---
    try:
        r = subprocess.run(['sudo', 'smartctl', '-H', dev], capture_output=True, text=True, timeout=10)
        output = r.stdout
        if 'PASSED' in output or 'OK' in output:
            disk['healthy'] = True
        elif 'FAILED' in output:
            disk['healthy'] = False
        else:
            disk['healthy'] = None
    except Exception as e:
        disk['error'] = str(e)

    # --- smartctl -A (attributes) for SATA ---
    try:
        r = subprocess.run(['sudo', 'smartctl', '-A', dev], capture_output=True, text=True, timeout=10)
        lines = r.stdout.splitlines()
        in_table = False
        for line in lines:
            if line.startswith('ID#'):
                in_table = True
                continue
            if in_table and line.strip():
                parts = line.split()
                if len(parts) >= 10:
                    attr = {
                        'id': int(parts[0]),
                        'name': parts[1],
                        'value': int(parts[3]),
                        'worst': int(parts[4]),
                        'thresh': int(parts[5]),
                        'raw': parts[9],
                        'type': parts[6],
                        'when_failed': parts[8] if parts[8] != '-' else None,
                    }
                    disk['attributes'].append(attr)
    except Exception:
        pass

    # --- smartctl -A for NVMe (different format) ---
    if 'nvme' in dev:
        try:
            r = subprocess.run(['sudo', 'smartctl', '-A', dev], capture_output=True, text=True, timeout=10)
            for line in r.stdout.splitlines():
                if ':' in line:
                    key, _, val = line.partition(':')
                    key = key.strip()
                    val = val.strip()
                    if key in ('Critical Warning', 'Temperature', 'Available Spare',
                               'Available Spare Threshold', 'Percentage Used',
                               'Data Units Read', 'Data Units Written',
                               'Power On Hours', 'Power Cycles',
                               'Unsafe Shutdowns', 'Media and Data Integrity Errors',
                               'Error Information Log Entries', 'Warning  Comp. Temp. Time',
                               'Critical Comp. Temp. Time'):
                        disk['attributes'].append({
                            'name': key,
                            'raw': val,
                        })
        except Exception:
            pass

    # Bestäm disktyp
    if 'nvme' in dev:
        disk['type'] = 'NVMe'
    elif disk['info'].get('Rotation Rate', '') == 'Solid State Device':
        disk['type'] = 'SSD'
    elif 'Rotation Rate' in disk['info']:
        disk['type'] = 'HDD'
    else:
        # Fallback: kolla attribut-ID:n direkt (mer tillförlitligt än namn)
        attr_ids = set(a.get('id', 0) for a in disk['attributes'])
        # ID 10 = Spin_Retry_Count, ID 3 = Spin_Up_Time → snurrande disk
        # ID 233 = Media_Wearout_Indicator, ID 177 = Wear_Leveling_Count → SSD
        if 10 in attr_ids or 3 in attr_ids:
            disk['type'] = 'HDD'
        elif 233 in attr_ids or 177 in attr_ids:
            disk['type'] = 'SSD'
        elif 'Model Family' in disk['info']:
            # Har Model Family → SATA-disk, troligen HDD om inte SSD-familj
            family = disk['info']['Model Family'].lower()
            if any(s in family for s in ('ssd', 'solid state')):
                disk['type'] = 'SSD'
            else:
                disk['type'] = 'HDD'
        elif 194 in attr_ids:
            disk['type'] = 'HDD'
        else:
            disk['type'] = 'Unknown'

    # Kort namn
    model = disk['info'].get('Device Model', disk['info'].get('Model Number', dev))
    disk['model'] = model

    results.append(disk)

print(json.dumps(results, indent=2))
"
