# OpenNebula AppMarket Static Generator

## Description

Generate your own marketplace appliances statically.

## Features

* Build your own marketplace
* Store your configuration in git
* Share virtual appliances across several OpenNebula instances
* Tight integration with OpenNebula

## Development

To contribute bug patches or new features, you can use the github Pull Request model. It is assumed that code and documentation are contributed under the Apache License 2.0. 

More info:
* [How to Contribute](http://opennebula.org/addons/contribute/)
* Support: [OpenNebula user forum](https://forum.opennebula.org/c/support)
* Development: [OpenNebula developers forum](https://forum.opennebula.org/c/development)
* Issues Tracking: Github issues

## Author

* Author: [kvaps](http://github.com/kvaps)

* Images metadata imported automatically from official [OpenNebula Marketplace](http://marketplace.opennebula.systems/) and managed by [OpenNebula Systems](http://opennebula.systems/).

## Compatibility

This add-on is compatible with OpenNebula 4.14.2+

## Driver Installation

Driver installation:

```
git clone https://github.com/kvaps/addon-appmarket-static
cp -r addon-appmarket-static/driver/static /var/lib/one/remotes/market/
```

Update `/etc/one/oned.conf`:

Add `static` into `MARKET_MAD` argumets:

```
MARKET_MAD = [
    EXECUTABLE = "one_market",
    ARGUMENTS  = "-t 15 -m http,s3,one,static"
]
```

After that create a new `TM_MAD_CONF` section:

```
MARKET_MAD_CONF = [
    NAME = "static",
    SUNSTONE_NAME  = "Statically Generated Marketplace",
    REQUIRED_ATTRS = "",
    APP_ACTIONS = "monitor",
    PUBLIC = "yes"
]
```

## Driver configuration

The following attributes can be used for configure marketplace

|    Attribute        |                     Description                |
| ---------------     | ---------------------------------------------- |
| `NAME`              | The name of the datastore                      |
| `ENDPOINT`          | URL to your metadata                           |
| `MARKET_MAD`        | Must be `static`                               |
| `BRIDGE_LIST`       | List of hosts used for downloading metadata    |


Create new marketplace:

```
cat > appmarket.conf <<EOT
NAME = "Static Marketplace"
MARKET_MAD = "static"
ENDPOINT = "https://raw.githubusercontent.com/kvaps/addon-appmarket-static/master/metadata"
EOT

onedatastore create market.conf
```

## Usage 

