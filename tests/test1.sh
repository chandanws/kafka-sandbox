#!/bin/bash

TOPIC="test1";

cd /opt/kafka

# Start Kafka instances
bin/kafka-server-start.sh -daemon config/server1.test1.properties; 
bin/kafka-server-start.sh -daemon config/server2.test1.properties;
bin/kafka-server-start.sh -daemon config/server3.test1.properties; 

sleep 2
instances=`ps -feawww | grep [D]kafka | wc -l`
while (($instances < 3)); do
  sleep 1;
done

# Destroy topic if already exist
topic_info=`/opt/kafka/bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC | wc -m`;
if (( $topic_info > 0)); then
  echo "Deleting existing topic"
  bin/kafka-topics.sh --delete --zookeeper localhost:2181 --topic $TOPIC
fi

# Create topic
bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic $TOPIC --replication-factor 3 --partitions 1

# Describe topic
echo "Description of topic $TOPIC"
bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC

echo "Fetching leader and replicas"
replicas=`bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC | grep Replicas | cut -d$'\t' -f5 | cut -d' ' -f2`
leader=`echo $replicas | cut -d',' -f1`
echo "Topic broker leader: $leader"

# Send messages
echo "About to send messages:"
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list localhost:9093,localhost:9092,localhost:9091 --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list localhost:9093,localhost:9092,localhost:9091 --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list localhost:9093,localhost:9092,localhost:9091 --topic $TOPIC --new-producer

# Kill replicas
total_servers=3
for i in $(seq 1 $total_servers); do  
	if (( $leader != $i)); then
		replica_pid=`ps -feawww | grep [D]kafka | grep "server$i" | awk '{ print $2 }'`
		echo "Killing replica $i with pid $replica_pid"
		`kill -9 $replica_pid` 
	fi
done

# Send data without any replicas active
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list localhost:909$leader --topic $TOPIC --new-producer
sleep 2

# Kill leader and restart replicas
echo "Killing leader listening on port 909$leader"
leader_pid=`ps -feawww | grep [D]kafka | grep "server$leader" | awk '{ print $2 }'`
kill -9 $leader_pid

echo "Bringing up replicas"
new_broker_list=""
for i in $(seq 1 $total_servers); do
   if (( $leader != $i)); then
       bin/kafka-server-start.sh -daemon config/server$i.test1.properties;
       new_broker_list="localhost:909$i,$new_broker_list"
   fi
done

echo "Trying to write to replicas $new_broker_list"
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer

bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC
new_leader=`bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC | grep -i leader | cut -d$'\t' -f4 | cut -d' ' -f2`
echo "New topic leader $new_leader"

echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer

# Startup former leader again
echo "Starting former leader"
bin/kafka-server-start.sh -daemon config/server$leader.test1.properties; sleep 5
reelected_leader=`bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $TOPIC | grep -i leader | cut -d$'\t' -f4 | cut -d' ' -f2`

echo "The reelected broker is: $reelected_leader"
if (($leader == $reelected_leader)); then
	echo "Former leader has been reelected!!!"
fi

echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer
echo "Random numbers $RANDOM" | bin/kafka-console-producer.sh --broker-list $new_broker_list --topic $TOPIC --new-producer

# Shutdown
echo "Shutting down"
bin/kafka-topics.sh --topic $TOPIC --delete --zookeeper localhost:2181
for i in $(seq 1 $total_servers); do
  pid=`ps -feawww | grep [D]kafka | grep "server$i" | awk '{ print $2 }'`
  echo "Killing kafka instance $i with pid $pid"
  `kill -9 $pid`
done
