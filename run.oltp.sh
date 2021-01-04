DATADIR=/data/mariadb-10.5.4
BACKUPDIR=/mnt/data/mariadb-10.5.4-copy

#MYSQLDIR=

set -x
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

startmysql(){
  sync
  sysctl -q -w vm.drop_caches=3
  echo 3 > /proc/sys/vm/drop_caches
  ulimit -n 1000000
  systemctl set-environment MYSQLD_OPTS="$1"
  systemctl start mysql-cd
}

shutdownmysql(){
  echo "Shutting mysqld down..."
  systemctl stop mysql-cd
  systemctl set-environment MYSQLD_OPTS=""
}

waitmysql(){
        set +e

        while true;
        do
                ${MYSQLDIR}mysql -h127.0.0.1 -Bse "SELECT 1" mysql

                if [ "$?" -eq 0 ]
                then
                        break
                fi

                sleep 30

                echo -n "."
        done
        set -e
}

initialstat(){
  cp $CONFIG $OUTDIR
  cp $0 $OUTDIR
}

collect_mysql_stats(){
  ${MYSQLDIR}mysqladmin ext -i10 > $OUTDIR/mysqladminext.txt &
  PIDMYSQLSTAT=$!
}
collect_dstat_stats(){
  vmstat 1 > $OUTDIR/vmstat.out &
  PIDDSTATSTAT=$!
}




RUNDIR=res-oltp-`hostname`-`date +%F-%H-%M`


#server: mariadb
#buffer_pool: 25
#randtype: uniform
#io_capacity: 15000
#storage: NVMe


BP=6
threads="1 2 4 8 16 32"
randtype="pareto"

for io in 100
do


# perform warmup
#./tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=3600 --threads=56 --report-interval=1 --tables=10 --scale=100 --use_fk=1 run |  tee -a $OUTDIR/res.txt

for i in $threads
do

runid="io$io.BP${BP}.threads${i}"

        OUTDIR=$RUNDIR/$runid
        mkdir -p $OUTDIR

echo "server: ps8" 		>> $OUTDIR/params.txt
echo "buffer_pool: $BP" 	>> $OUTDIR/params.txt
echo "randtype: $randtype" 	>> $OUTDIR/params.txt
echo "threads: $i" 		>> $OUTDIR/params.txt
echo "host: `hostname`" 	>> $OUTDIR/params.txt

        # start stats collection


        time=300
        sysbench oltp_point_select --threads=$i --time=$time --tables=1 --table_size=1000000 --mysql-host=10.2.0.12 --mysql-user=sbtest --mysql-password=sbtest --max-requests=0 --report-interval=1 --mysql-db=sbtest --mysql-ssl=off --create_table_options='DEFAULT CHARSET=utf8mb4' --report_csv=yes --rand-type=$randtype --histogram=on --percentile=99 run |  tee -a $OUTDIR/results.txt
#        /mnt/data/vadim/bench/sysbench-tpcc/tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=$time --threads=$i --report-interval=1 --tables=10 --scale=100 --use_fk=0 --report-csv=yes run |  tee -a $OUTDIR/res.thr${i}.txt


        sleep 30
done

shutdownmysql

done
