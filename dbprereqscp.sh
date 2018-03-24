#!/bin/bash
#launchrollover=true
#launchrollover=true/false
dbname=$1
#dbname=$1
if [ -z "$dbname" ]; then 
   echo "please enter ./dbprerqs <dbinstanceidentifier> <true>(to launch rollback instance / leave blank to not)" 
        exit
else 
    echo "db instance accepted"
fi
datetime=$(date +%Y%m%d%H%M%S)
echo $datetime
parameter=$(aws rds describe-db-instances --db-instance-identifier $dbname | grep '\"\DBParameterGroupName\"\:' | sed 's/^.*: //' | sed 's/,//' | tr -d '"')
echo $parameter
subnetgroupname=$(aws rds describe-db-instances --db-instance-identifier $dbname | grep '\"\DBSubnetGroupName\"\:' | sed 's/^.*: //' | sed 's/,//' | tr -d '"')
echo $subnetgroupname
#aws rds create-db-instance --db-instance-identifier $dbname --db-instance-class db.t2.micro --engine mysql --master-username george --master-user-password apitester --allocated-storage 20
aws rds wait db-instance-available --db-instance-identifier $dbname
echo "Initiating Snapshot"
aws rds create-db-snapshot --db-instance-identifier $dbname --db-snapshot-identifier $dbname$datetime
until aws rds describe-db-snapshots --db-snapshot-identifier $dbname$datetime | grep -i available; do sleep 10; done
if [ "$2" == "true" ]; then
    echo "Restoring Rollback DB"
    aws rds restore-db-instance-from-db-snapshot --db-instance-identifier $dbname-rollback --db-snapshot-identifier $dbname$datetime --db-subnet-group-name $subnetgroupname --multi-az
    aws rds wait db-instance-available --db-instance-identifier $dbname-rollback
    aws rds modify-db-instance --db-instance-identifier $dbname-rollback --db-parameter-group-name $parameter
    until aws rds describe-db-instances --db-instance-identifier $dbname-rollback | grep $parameter; do sleep 10; done
    until aws rds describe-db-instances --db-instance-identifier $dbname-rollback | grep pending-reboot; do sleep 10; done
    aws rds wait db-instance-available --db-instance-identifier $dbname-rollback
    aws rds reboot-db-instance --db-instance-identifier $dbname-rollback 
    if aws rds describe-db-instances --db-instance-identifier $dbname-rollback | grep in-sync; then
    echo "parameter application sucsessfull. database available"
else
    echo FAILURE
fi
else 
    echo snapshot created
fi