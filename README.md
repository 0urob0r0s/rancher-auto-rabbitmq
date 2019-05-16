# Automatic RabbitMQ Rancher based Cluster

 **Overview**

This container provides a Single instance / Automatic Clustered RabbitMQ Service.

**Caveats**

This docker image will not work on standard docker environments as it relies on Rancher's Metadata Service for the autodiscovery feature. 

**Features**

- Fully configurable through Docker ENV vars
- Clustered RabbitMQ support
- Automatic node Discovery

**Usage**

*Example Docker Compose - Multinode Cluster deployment*

```
version: '2'
services:
  MessageQueue:
    image: rancher-auto-rabbitmq:latest
    environment:
      RABBITMQ_ERLANG_COOKIE: abcdefgh
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    stdin_open: true
    volumes:
    - /opt/volumes/rabbitmq:/var/lib/rabbitmq
    tty: true
    ports:
    - 15672:15672/tcp
    - 5672:5672/tcp
    labels:
      io.rancher.scheduler.global: 'true'
      io.rancher.container.hostname_override: container_name
```

*Example Rancher Compose - Healthcheck Settings*

```
version: '2'
services:
  MessageQueue:
    retain_ip: true
    start_on_create: true
    health_check:
      response_timeout: 2000
      healthy_threshold: 2
      port: 5672
      unhealthy_threshold: 3
      initializing_timeout: 60000
      interval: 2000
      strategy: recreate
      reinitializing_timeout: 60000
```

**Notes**

RABBITMQ_ERLANG_COOKIE is required for Node Clustering
If not specified, user/pass = guest/guest.


**Head over the repo `docker-adv-rt` for a more complex example.**
