#!/bin/bash

RANCHER_SERVICE_NAME=$(curl --retry 5 --retry-delay 5 --connect-timeout 3 -s http://rancher-metadata/2015-07-25/self/service/name)

# Exeucte if deploying to Rancher
if [ $RANCHER_SERVICE_NAME ] ; then

    # Rancher service name
  echo "RANCHER_SERVICE_NAME: ${RANCHER_SERVICE_NAME}"

  # Rancher stack name
  STACK_NAME=$(curl --retry 5 --retry-delay 5 --connect-timeout 3 -s http://rancher-metadata/2015-07-25/self/stack/name)
  echo "STACK_NAME: ${STACK_NAME}"

  # Number of container instances running as part of service (i.e. scale)
  SERVICE_INSTANCES=$(curl --retry 5 --retry-delay 5 --connect-timeout 3 -s http://rancher-metadata/2015-07-25/services/${RANCHER_SERVICE_NAME}/containers | wc -l)
  echo "SERVICE_INSTANCES: ${SERVICE_INSTANCES}"

  # Set RabbitMQ hostname to equal that of Container name
  export HOSTNAME=$(curl --retry 5 --retry-delay 5 --connect-timeout 3 -s http://rancher-metadata/2015-07-25/self/container/name)
  echo "HOSTNAME: ${HOSTNAME}"

  # Cluster with first instance listed in service (only if mulitple instances)
  if [ $SERVICE_INSTANCES -gt 1 ]; then
    MASTER=$(curl --retry 5 --retry-delay 5 --connect-timeout 3 -s http://rancher-metadata/2015-07-25/services/${RANCHER_SERVICE_NAME}/containers/0)
    if [ $MASTER != $HOSTNAME ]; then
      CLUSTER_WITH=$MASTER
      echo "CLUSTER_WITH: ${CLUSTER_WITH}"
    fi
  fi
fi

# Handle clustering (only join cluster if at least one instance exists and clustering enabled)
set -m

if [ -z "$CLUSTER_WITH" ] ; then
  /usr/lib/rabbitmq/bin/rabbitmq-server
else
  # Give master instance time to start up when laucnh all instances at same time via rancher-compose
  sleep 5

  if [ -f /.CLUSTERED ] ; then
    # Handles container restart case
    /usr/lib/rabbitmq/bin/rabbitmq-server
  else
    # Handles container new (from scracth or after delete operation) case
    touch /.CLUSTERED

    # When restarting a container, RabbitMQ will fail to boot with some a
    # message like:
    #
    # Error description:
    #    {could_not_start,rabbitmq_management,
    #        {{shutdown,
    #             {failed_to_start_child,rabbit_mgmt_sup,
    #                 {'EXIT',
    #                     {{shutdown,
    #                          [{{already_started,<7115.1406.0>},
    #                            {child,undefined,rabbit_mgmt_db,
    #                                {rabbit_mgmt_db,start_link,[]},
    #                                permanent,4294967295,worker,
    #                                [rabbit_mgmt_db]}}]},
    #                      {gen_server2,call,
    #                          [<0.368.0>,{init,<0.366.0>},infinity]}}}}},
    #         {rabbit_mgmt_app,start,[normal,[]]}}}
    #
    # This is fixed by first using the RabbitMW Control tool to remove the
    # old hostname.
    echo ""
    echo "Removing current hostname from cluster.  Ignore any error stating not in cluster or node is not a cluster"
    rabbitmqctl -n rabbit@$CLUSTER_WITH forget_cluster_node rabbit@$HOSTNAME
    sleep 5

    /usr/lib/rabbitmq/bin/rabbitmq-server &
    sleep 10

    rabbitmqctl stop_app
    rabbitmqctl join_cluster rabbit@$CLUSTER_WITH
    rabbitmqctl start_app

    # Bring rabbit back to the foreground for Docker management
    fg
  fi
fi

