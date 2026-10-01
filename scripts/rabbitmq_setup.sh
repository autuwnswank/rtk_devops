#!/bin/bash
sudo rabbitmqctl add_user viewer viewer
sudo rabbitmqctl set_user_tags viewer monitoring
sudo rabbitmqctl set_permissions -p / viewer "" "" ".*"
sudo rabbitmqadmin declare queue name=rtk-queue durable=true arguments='{"x-queue-type": "quorum"}'
sudo rabbitmq-queues quorum_status rtk-queue
