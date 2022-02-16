#!/usr/bin/env bash

# created by dimasadriansah4@gmail.com

# How to run
# ./backup-mysql.sh <sudo-password> <mysql-password>

# Define Variable
BACKUP_DIR="/path/to/backup/dir" || exit 1 # lokasi direktori untuk menyimpan file backup
VOLUME_DIR="/path/to/volume/in/host" || exit 1 # lokasi direktori volume dari container/pod
NAMESPACE="namespace-database" || exit 1 # namespace dimana aplikasi berjalan
DATABASE_DRIVER="mysql" || exit 1 # keyword: mysql - postgres - mongo
VOLUME_POD="/path/to/volume/in/pod" || exit 1 # lokasi direktori didalam pod yang divolume ke host
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S) # tanggal untuk penamaan file backup
SUDO_PASSWORD=$1 # password sudo host
DB_PASSWORD=$2 # password user database
DATABASE_NAME="
    database-foo database-bar
    database1 database2
    "

# Provisioning
checking_backup_dir(){
    cd ~/
    echo [ $(date) ] [ Directory backup ] INFO: Checking directory backup ...
    sleep 4

    if [ -e $BACKUP_DIR ]; then
        echo [ $(date) ] [ Directory backup ] INFO: Directory backup are found!
        sleep 1
        echo [ $(date) ] [ Directory backup ] INFO: $BACKUP_DIR
        sleep 2
    else
        echo [ $(date) ] [ Directory backup ] WARNING: Directory backup are not exists
        sleep 1
        echo [ $(date) ] [ Directory backup ] INFO: Creating directory backup
        sleep 2
        mkdir -p $BACKUP_DIR || exit 1

        if [ -e $BACKUP_DIR ]; then
            echo [ $(date) ] [ Directory backup ] INFO: Directory backup has been created!
            sleep 2
            echo [ $(date) ] [ Directory backup ] INFO: $BACKUP_DIR
        else
            echo [ $(date) ] [ Directory backup ] WARNING: Directory backup are not created
            sleep 2
            exit 1
        fi
    fi
}

checking_pod_volume(){
    cd ~/
    echo [ $(date) ] [ Pod volume ] INFO: Checking pod volume ...
    sleep 4

    if [ -e $VOLUME_DIR ]; then
        echo [ $(date) ] [ Pod volume ] INFO: Pod volume are found!
        sleep 1
        echo [ $(date) ] [ Pod volume ] INFO: $VOLUME_DIR
        sleep 2
    else
        echo [ $(date) ] [ Pod volume ] WARNING: Pod volume are not found!
        sleep 2
        echo [ $(date) ] [ Pod volume ] WARNING: Please create your pod volume!
        exit 1
    fi
}

checking_pod_status(){
    cd ~/
    echo [ $(date) ] [ Pod status ] INFO: Checking pod name ...
    sleep 4
    export POD_NAME=$(kubectl get pods -n $NAMESPACE | grep $DATABASE_DRIVER | awk '{print $1;}')
    sleep 1

    if [[ $POD_NAME = *$(kubectl get pods -n $NAMESPACE | grep $DATABASE_DRIVER | awk '{print $1;}')* ]]; then
        echo [ $(date) ] [ Pod status ] INFO: Pod name is $POD_NAME
        sleep 2

        echo [ $(date) ] [ Pod status ] INFO: Checking pod status ...
        sleep 4

        if [[ $(kubectl get pods -n $NAMESPACE | grep $DATABASE_DRIVER | awk '{print $3;}') = *Running* ]]; then
            echo [ $(date) ] [ Pod status ] INFO: $POD_NAME is Running
            sleep 2
        else
            echo [ $(date) ] [ Pod status ] WARNING: $POD_NAME is $(kubectl get pods -n $NAMESPACE | grep $DATABASE_DRIVER | awk '{print $3;}')
            sleep 1
            exit 1
        fi
    else
        echo [ $(date) ] [ Pod status ] ERROR: Pod does not exists
        sleep 1
        exit 1
    fi
}

backup_database(){
    cd ~/
    echo [ $(date) ] [ Backup database ] INFO: Checking sudo password ...
    sleep 2

    if [ ! -z $SUDO_PASSWORD ]; then
        if [[ $(echo $SUDO_PASSWORD | sudo -S echo check &> /dev/null && echo right || echo wrong) = *right* ]]; then
            echo [ $(date) ] [ Backup database ] INFO: Your password are right!
            sleep 3

            if [ ! -z $DB_PASSWORD ]; then
                echo [ $(date) ] [ Backup database ] INFO: Checking database password ...
                sleep 2
                
                if [[ $(kubectl exec -it $POD_NAME -n $NAMESPACE -- bash -c "mysql -u root -p$DB_PASSWORD -e exit" &> /dev/null || echo wrong) = *wrong* ]]; then
                    echo [ $(date) ] [ Backup database ] WARNING: Database password are wrong!
                    sleep 2
                    exit 1
                else
                    echo [ $(date) ] [ Backup database ] INFO: Your database password are right!
                    sleep 2
                    true
                fi

                echo [ $(date) ] [ Backup database ] INFO: Starting backup database ...
                sleep 3

                for DATABASE in $DATABASE_NAME
                do 
                    if [[ $(kubectl exec -it $POD_NAME -n $NAMESPACE -- bash -c "cd $VOLUME_POD ; mysqldump -u root -p$DB_PASSWORD $DATABASE > $DATABASE.sql" &> /dev/null || echo wrong) = *wrong* ]]; then
                        echo [ $(date) ] [ Backup database ] WARNING: Database $DATABASE does not exists!
                        kubectl exec -it $POD_NAME -n $NAMESPACE -- bash -c "cd $VOLUME_POD ; rm $DATABASE.sql"
                        sleep 2
                        true
                    else
                        echo [ $(date) ] [ Backup database ] INFO: Database $DATABASE has been backup
                        sleep 2
                        true
                    fi
                done
            else
                echo [ $(date) ] [ Backup database ] WARNING: Please input your password of user database!
                sleep 2
                echo [ $(date) ] '[ Backup database ] HINT: ./backup.sh <sudo-password> <mysql-password>'
                exit 1
            fi
        elif [[ $(echo $SUDO_PASSWORD | sudo -S echo right &> /dev/null || echo wrong) = *wrong* ]]; then
            echo [ $(date) ] [ Backup database ] WARNING: Your password are wrong!
            sleep 2
            exit 1
        else
            echo [ $(date) ] [ Backup database ] WARNING: Your password have something problem!
            exit 1
        fi
    else
        echo [ $(date) ] [ Backup database ] WARNING: Please input your sudo password!
        sleep 2
        echo [ $(date) ] '[ Backup database ] HINT: ./backup-mysql.sh <sudo-password> <mysql-password>'
        exit 1 
    fi

}

compress_file(){
    cd ~/
    echo [ $(date) ] [ Compress file ] INFO: Backup file will be move to $BACKUP_DIR
    sleep 4
    echo [ $(date) ] '[ Compress file ] INFO: Wait minutes a second until backup file has been moved'
    sleep 2

    for DATABASE in $DATABASE_NAME
    do
        echo $SUDO_PASSWORD | sudo -S mv $VOLUME_DIR/$DATABASE.sql $BACKUP_DIR &> /dev/null
        echo $SUDO_PASSWORD | sudo -S chown -R $USER:$USER $BACKUP_DIR/$DATABASE.sql
    done
    echo [ $(date) ] [ Compress file ] INFO: File backup has been move to $BACKUP_DIR
    sleep 2
    echo [ $(date) ] [ Compress file ] INFO: File backup will be compress to tar format
    sleep 2
    echo [ $(date) ] [ Compress file ] INFO: Starting compress a file ...
    sleep 3
    cd $BACKUP_DIR && tar cvf backup-db-file_$TIMESTAMP.tar ./*.sql &> /dev/null || exit 1
    rm $BACKUP_DIR/*.sql
    sleep 1
    if [ -e $BACKUP_DIR/backup-db-file_$TIMESTAMP.tar ]; then
        echo [ $(date) ] [ Compress file ] INFO: a file has been to compress
        sleep 2
        echo [ $(date) ] [ Compress file ] INFO: Done! Have a nice day!
        sleep 1
    else
        echo [ $(date) ] [ Compress file ] WARNING: a file failed to compress
        sleep 2
        exit 1
    fi
}

# call a function below here for running job script
checking_backup_dir
checking_pod_volume
checking_pod_status
backup_database
compress_file