sudo hostname kafka-server

sudo apt-get update
sudo apt-get install -y patch
sudo apt-get install -y make
sudo apt-get install -y build-essential
sudo apt-get install -y wget
sudo apt-get install -y htop
sudo apt-get install -y openjdk-7-jdk
sudo apt-get install -y scala

wget http://mirrors.ukfast.co.uk/sites/ftp.apache.org/zookeeper/stable/zookeeper-3.4.6.tar.gz
tar -xvf zookeeper-3.4.6.tar.gz -C /opt
mv /opt/zookeeper-3.4.6 /opt/zookeeper
cd /opt/zookeeper
cp conf/zoo_sample.cfg conf/zoo.cfg
bin/zkServer.sh start &

wget http://supergsego.com/apache/kafka/0.8.2.1/kafka_2.10-0.8.2.1.tgz
tar -xvzf kafka_2.10-0.8.2.1.tgz -C /opt
mv /opt/kafka_2.10-0.8.2.1 /opt/kafka
cd /opt/kafka
cp /vagrant/provision/config/*.properties /opt/kafka/config

chwon vagrant /opt/kafka

cp /vagrant/tests/* /home/vagrant
chmod 777 test1.sh
