# OpenNebula Static Marketplace

## Description

Generate your own marketplace appliances statically.

![screenshot](screenshot.png)

## Demo

Marketplace with appliances imported from the official OpenNebula Marketplace:

* **[OpenNebula Static Marketplace](https://raw.githack.com/kvaps/opennebula-static-marketplace/master/exampleSite/public/index.html)**

Marketplace with own appliances:

* **[WEDOS OpenNebula Marketplace](https://marketplace.opennebula.wedos.cloud/)**


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

  **If you want to generate you own images please take a look on [OpenNebula Images Generator](https://github.com/kvaps/opennebula-images) project.**

## Compatibility

This add-on is compatible with OpenNebula 4.14.2+

## Driver Installation

Driver installation:

```
git clone https://github.com/kvaps/opennebula-static-marketplace
cp -r opennebula-static-marketplace/driver/static /var/lib/one/remotes/market/
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
| `NAME`              | The name of the marketplace                    |
| `ENDPOINT`          | URL to your metadata file                      |
| `MARKET_MAD`        | Must be `static`                               |
| `BRIDGE_LIST`       | List of hosts used for downloading metadata    |


Create new marketplace:

```
cat > appmarket.conf <<EOT
NAME = "Static Marketplace"
MARKET_MAD = "static"
ENDPOINT = "https://github.com/kvaps/opennebula-static-marketplace/raw/master/exampleSite/public/metadata/index.html"
EOT

onedatastore create appmarket.conf
```

## Usage 

For creating your own marketplace:

1. Install [Hugo](https://github.com/gohugoio/hugo)

2. Initialize new site and marketplace theme:

   ```bash
   hugo new site marketplace -f yaml
   cd marketplace
   git clone https://github.com/kvaps/opennebula-static-marketplace themes/opennebula-static-marketplace
   cp -r themes/opennebula-static-marketplace/content/metadata/ content/metadata/
   echo 'theme: opennebula-static-marketplace' > config.yaml
   ```


3. Describe your appliance using yaml sytax and save it into `data/appliances/myapp.yaml` *(use examples from [exampleSite](exampleSite/data/appliances) directory)*

4. Generate new site

   ```bash
   hugo
   ```

5. Upload generated site from `public/*` or just metadata `public/metadata/index.html` to some HTTP or S3-server and provide access to it

6. Specify url in `ENDPOINT` variable to the static marketplace driver in OpenNebula

