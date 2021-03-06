#!/bin/bash

export PGHOST=localhost
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE=local_zmon_db

container=$(docker ps | grep postgres:9.4.0)
if [ -z "$container" ]; then
    docker rm postgres
    docker run --name postgres --net host -e POSTGRES_PASSWORD=postgres -d postgres:9.4.0
fi

until nc -w 5 -z localhost 5432; do
    echo 'Waiting for Postgres port..'
    sleep 3
done

cd /home/vagrant/zmon-controller/database/zmon
psql -c "CREATE DATABASE $PGDATABASE;" postgres
psql -c 'CREATE EXTENSION hstore;'
find -name '*.sql' | sort | xargs cat | psql
psql -f /vagrant/vagrant/initial.sql
psql -f /home/vagrant/zmon-eventlog-service/database/eventlog/00_create_schema.sql

container=$(docker ps | grep redis)
if [ -z "$container" ]; then
    docker rm redis
    docker run --name redis --net host -d redis
fi

until nc -w 5 -z localhost 6379; do
    echo 'Waiting for Redis port..'
    sleep 3
done

ip=$(ip -o -4 a show eth0|awk '{print $4}' | cut -d/ -f 1)

container=$(docker ps | grep cassandra)
if [ -z "$container" ]; then
    docker rm cassandra
    docker run --name cassandra --net host -d abh1nav/cassandra:latest
fi

until nc -w 5 -z $ip 9160; do
    echo 'Waiting for Cassandra port..'
    sleep 3
done

container=$(docker ps | grep kairosdb)
if [ -z "$container" ]; then
    docker rm kairosdb
    docker run --name kairosdb --net host -d -e "CASSANDRA_HOST_LIST=$ip:9160" wangdrew/kairosdb
fi

until nc -w 5 -z localhost 8083; do
    echo 'Waiting for KairosDB port..'
    sleep 3
done

/vagrant/vagrant/start-services.sh
