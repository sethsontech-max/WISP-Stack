### Under Construction
#### To Dos
1. ~~Update documentation and git~~
    1. ~~Document device IPs/target files and methods~~
1. ~~Add AF60 MicroTower Airtime graphs to main dashboard~~
1. ~~declare main/default grafana dashboard as nemo Dashboard~~
1. modify and clean up ubiquiti drilldown dashboard
1. ~~fix Nemo Dashboard Waning log / device panel - currently shows incorrect values~~
    1. fixed by deleting loki volume to remove old config data
1. add logging to all docker containers
1. create Container log dashboard
1. Add web based file editor container - provide means of adjusting targets easily with documentation
    1. code-server - VS code web browser is probably best option
1. setup basic authentication checks - password logins - to prevent unwanted edits
    1. ~~Grafana~~
1. determine backup and transfer method
    1. Move stack to linux machine for more hardware resource
1. investigate ways to have high avialability setup include mirrors of volume data storage


#### Possible Future Imporvments
1. add unifi snmp data to track unifi UPS and cameras offline status (more future improvement and needed)
1. send all ubiquiti device logs to server
    1. add local DNS name to router to point in case IP address changes
1. Create program to perfrom IP scan and compare against all targets - allows for checking if unmonitored devices are present when compared to target list. As well as ping status of devices.
1. Reduce SNMP metrics for Mikrotik devices as they are not needed with API metrics. SNMP is only needed for easy UP status indicator for grafana
1. implement parrallel target processing for faster scraping time
1. Create method to integrate target with sonar (bi-directionally?)
1. investigate and implement dynmaic data sampling to allow faster dashboard loading

### Description
This is a customized docker stack based on [MKTXP-Stack](https://github.com/akpw/mktxp-stack) designed for data collection and logging of network elements, primarily Ubiquiti AirMax/AF60 and MikroTik RouterOS devices. The primary use is for managing WISP deployment with vizualizations and dashboards not available in existing tools.

Primary functions are quick view of total throughput, APs airtime is exceeding thresholds, any station who have changed ssid values, as well as dashboards for viewing indepth per device metrics (regardless of manufacturer) and logs.

The current dashboards are heavily customized for our specific setup. Significant adjustments will need to be made to be used for other configurations.

#### Included Programs and their use
* [Grafana](https://github.com/grafana/grafana) - Data visualization and dashboard platform
* [Prometheus](https://github.com/prometheus/prometheus) - Time series database and monitoring system
  * [SNMP-Exporter](https://github.com/prometheus/snmp_exporter) - Scrapes SNMP data from network devices
    * [SNMP Generator](https://github.com/prometheus/snmp_exporter/tree/main/generator) - Creates SNMP MIB/OID mapping files based on devices and manufacturers to be monitored
  * [MKTXP](https://github.com/akpw/mktxp) - MikroTik Exporter: uses RouterOS API to gather device metrics and statistics
* [Loki](https://github.com/grafana/loki) - Log aggregation system designed for storing and querying logs
  * [Promtail](https://github.com/grafana/loki/tree/main/clients/promtail) - Log shipping agent that collects and forwards logs to Loki
  * [syslog-ng](https://github.com/syslog-ng/syslog-ng) - Advanced syslog daemon for collecting, processing, and forwarding log messages from network devices
* SSID-change-detector - A custom Docker container designed to detect when Ubiquiti AirMax stations switch to their designated backup or secondary SSID connection. 

##### SSID-Change-Detector Description

A custom Docker container designed to detect when Ubiquiti AirMax stations switch to their designated backup or secondary SSID connection. This is useful notification for determing soft failures and manually reverting the station back to the primary connection. Unfortunately, I was unable to determine a different method to perform this function using existing tools.

The container is based on Alpine Linux and queries Prometheus to monitor changes in the "ubntWlStatSsid" label over time. It compares the current value against its value from a previous interval (configurable via `LOOKBACK_INTERVAL`, default: 300s). When a change is detected, it logs the event. The Loki Docker plugin pushes these logs to Loki for visualization in Grafana.

### File Setup and Targets

#### SNMP Devices
To adjust or change which devices (called targets) are monitored or scraped, modify the appropriate YAML configuration files.

For devices using SNMP data, targets are declared in YAML files organized by device type, located in:
```
Prometheus
└── Targets
    ├── mikrotik_routeros_targets.yml
    ├── ubiquiti_af60_targets.yml
    ├── ubiquiti_airfiber_targets.yml
    ├── ubiquiti_airmax_targets.yml
    ├── Ubiquiti_UISP_P_targets.yml
    └── Ubiquiti_UISP_S_targets.yml
```

Place device IPs in the YAML file associated with the device type based on the filename. Targets will automatically update after a few minutes without intervention.

#### Example Configuration:
You can define multiple target groups within each file to assign custom labels per device. This is useful for filtering devices in Grafana queries. For example, the AirMax YAML file contains multiple target groups with the role label of "ColdSpares"`, `"Infrastructure-Maintenance"`, `"Cancelled-unrecovered"`, or `"misc"`. This allows devices that don't need active monitoring to be excluded from Grafana dashboard queries.

```
- targets:
  - 10.10.10.37
  - 10.10.10.38
  labels:
    site: "Sass"
    device_type: "AF60"
    link_type: "backhaul"

- targets:
  - 10.10.10.39
  - 10.10.10.40
  labels:
    site: "WaterTower"
    device_type: "AF60"
    link_type: "backhaul"
```
#### MikroTik Devices

For MikroTik devices using the API targets need to be declared in mktxp/mktxp.conf. Please see the [mktxp docs](https://github.com/akpw/mktxp) for format rules and options.

In this case, Mikrotik devices main metrics are being called by the API. But they are also listed in the SNMP targets. This is to allow easier determination of device up/down status in grafana as the mktxp exporter does not have a builtin implementation of this.

### Requirements:
1. [Docker](https://docs.docker.com)
1. [Docker Compose](https://docs.docker.com/compose/install/)
1. [Docker Loki plugin](https://grafana.com/docs/loki/latest/send-data/docker-driver/configuration/)
1. The host machine must have direct IPv4 access to monitored devices. Ideally, host is in same LAN.



### Install & Getting Started:
 - Clone this repository (or download zip with wget)
```
git clone [insert URL]
cd mktxp-stack
```
- setup Loki plugin

for amd64 (linux)

```
docker plugin install grafana/loki-docker-driver:3.6.0-amd64 --alias loki --grant-all-permissions
```

for arm64 (raspberry Pi)
```
docker plugin install grafana/loki-docker-driver:3.6.0-arm64 --alias loki --grant-all-permissions
```
verify working with
```
docker plugin ls
```

start docker compose for the first time using current primary file. We will need to build the custom docker container.

```
sudo docker-compose -f docker-compose-mktxp-stack-fs.yml up -d --build ssid-change-detector
```

After building, the stack can be taken up and down with standard docker commands:
```
sudo docker-compose -f docker-compose-mktxp-stack-fs.yml up -d

sudo docker-compose -f docker-compose-mktxp-stack-fs.yml down
```

### Notes

1. Still in development
1. development occured on a raspberry pi to start with (as that was what was available at the time). As a result, there were issues with getting Go to run in order to make use of the snmp-exporter snmp.yml generator. A seperate linux machine was used to do this.