Vagrant image that deploys 3 instances of Kafka brokers to push data and allows you to test some of the replication features of Kafka.

## Goal:

The main purpose is create a VM that will allow the simulation of certain cases where you want to test the Kafka replication functionality.

Kafka's replication features are top notch. All the writes and reads go to the leader of the topic or the partition but the data is replicated to other brokers for purposes of having copies of the data somewhere else. This of course requires a lot of coordination and synchronization and lots of checks to make sure that your replicas are not that far behind the leader. That also requires a way to check for the liveness of the replicas and how in Sync they are. Kafka uses Zookeeper to help with some of that coordination but it also maintains a list of `in-sync replicas` or ISR. 

A replica is out of sync if it is unreacheable from Zookeeper (heartbeat purposes) or when the replica is behind `X` number of messages from the leader. `X` is set in the property `replica.lag.max.messages`. So if the replica is alive but too slow (greater than `replica.lag.max.messages`) then it is removed from the list of `in-sync replicas` so if the service is unable to reach Zookeeper (network partition, service shutdown, GC pause, etc) 

You can specify a minimum number of replicas in the ISR list needed to `commit` messages to the consumer. In Kafka a commit is the action of sending the event to the consumer. The topic/partition leader won't send updates to consumers unless they have been replicated to a minimum number of replicas, configured with the property `min.insync.replicas`. The default value is 1 and the leader is considered as a replica (so by default it survives without any replica). So if you have 3 brokers and you `min.insync.replicas=3` that means that all your 3 servers should be up and healthy for Kafka to send updates. 

### Leader Election when there's a fail over

When the leader of a topic or partition fails, Kafka decides who'll take ownership using two criterias:

* Preferred leader election: if a leader goes down a new one is elected. Once it comes back, it catches up with the messages missed while gone and then is selected again as the leader.
* Unclean leader election: a replica out of sync might be chosen as a leader if there's no replicas in the ISR list.
** This is a tradeoff between consistency and high availability.
** This feature is controlled with the property "unclean.leader.election.enable". When disabled (unclean.leader.election.enable=false) if  leader goes down and the ISR is empty then the topic/partition will be unavailable until a leader is elected again.

So in my mind, the main take away is that with Kafka you get to chose how you setup your brokers and what tradeoffs you want to make in terms of high consistency or high availability. 

The settings for the Kafka brokers in this project make use of properties described above and are only intended to create situations where you can see the replication process working. One case for example, could be having replicas running behind and then killing the leader and see if the replica gets elected or not.

## Tests

### At least one replica is present

Focus: high availability. 
Goal: In case of replicas going down and eventually the leader going down and replicas being out of sync, it should be able to send messages when replicas are restarted.
Description: create a new topic with replication factor of 3 and `replica.lag.max.messages` = 5 (replicas can't be more than 5 messages behind). Start sending messages, then kill brokers 2 and 3. Consumer should keep receiving messages. Kill leader, sleep 5 seconds and keep sending messages (they will fail). Startup replicas. 
Expected result: consumer should receive messages after the leader was killed. Notice also how the consumer receives messages (the broker `commits`) even though the partitions are down because of the `min.insync.replicas` property that is defaulting to 1 (the leader)

View after the topic was created:
```
Topic:test1	PartitionCount:1	ReplicationFactor:3	Configs:
	Topic: test1	Partition: 0	Leader: 1	Replicas: 2,3,1	Isr: 1,2,3
```

Steps:
* Enter your VM console using `vagrant ssh`.
* Open a new console using `vagrant ssh` and type: `/opt/kafka/bin/kafka-console-consumer.sh --zookeeper 127.0.0.1:2181 --topic test1 `
* Execute `./test1.sh`

You'll see some errors in both the producer (the test) and the consumer as they will lose connectivity to the brokers but they'll eventually catch up.  

Example:
```
[2016-02-10 05:18:08,444] WARN Error in I/O with localhost/127.0.0.1 (org.apache.kafka.common.network.Selector)
java.net.ConnectException: Connection refused
	at sun.nio.ch.SocketChannelImpl.checkConnect(Native Method)
	at sun.nio.ch.SocketChannelImpl.finishConnect(SocketChannelImpl.java:744)
	at org.apache.kafka.common.network.Selector.poll(Selector.java:238)
	at org.apache.kafka.clients.NetworkClient.poll(NetworkClient.java:192)
	at org.apache.kafka.clients.producer.internals.Sender.run(Sender.java:191)
	at org.apache.kafka.clients.producer.internals.Sender.run(Sender.java:122)
	at java.lang.Thread.run(Thread.java:745)
```

And for the consumer, once the test is done the brokers are shut down and you'll see messages like the one below as it is unable to reconnect: 

```
2016-02-10 05:18:38,851] WARN Fetching topic metadata with correlation id 62 for topics [Set(test1)] from broker [id:1,host:127.0.0.1,port:9091] failed (kafka.client.ClientUtils$)
java.nio.channels.ClosedChannelException
	at kafka.network.BlockingChannel.send(BlockingChannel.scala:100)
	at kafka.producer.SyncProducer.liftedTree1$1(SyncProducer.scala:73)
	at kafka.producer.SyncProducer.kafka$producer$SyncProducer$$doSend(SyncProducer.scala:72)
	at kafka.producer.SyncProducer.send(SyncProducer.scala:113)
	at kafka.client.ClientUtils$.fetchTopicMetadata(ClientUtils.scala:58)
	at kafka.client.ClientUtils$.fetchTopicMetadata(ClientUtils.scala:93)
	at kafka.consumer.ConsumerFetcherManager$LeaderFinderThread.doWork(ConsumerFetcherManager.scala:66)
	at kafka.utils.ShutdownableThread.run(ShutdownableThread.scala:60)
```

## Instructions:

* Download and install vagrant: https://www.vagrantup.com/downloads.html
* Clone this repo.
* Execute the following command: `vagrant up`. It will take a bit but eventually everything will get installed.
* Login to the VM by using `vagrant ssh`.
* Execute desired test as described above.
