#!/bin/sh
# Luiz Sales
# luiz@lsales.biz
# 
# Criar um mapa de rede dinamicamente.


IFS=$'\n'
HOSTID="10368"
FILE=$1
DeviceID_line=$(cat -n $FILE | grep "Device ID" | awk '{print $1}')
Devices_lines_i=$(echo "$DeviceID_line + 1" | bc)
Total_line=$(cat -n $FILE | grep "Total entries displayed" | awk '{print $1}')
Total_Interval=$(echo "$Total_line - 2" | bc)
SW_MASTER=$(cat $FILE | head -n1 | awk -F\# '{print $1}')


awk "NR>=$Devices_lines_i && NR<=$Total_Interval" $FILE > HOLD
#sed -n "'$Devices_lines_i','$Total_Interval p'" $FILE
echo > HOLD.NS

echo "$SW_MASTER" 
echo "|"
IFS=$'\n'
for x in `cat HOLD`
do
	VIZINHO=$(echo $x | awk '{print $1}')
	VizinhoPort=$(echo $x | awk '{print $2}')
	SW_MASTER_PORT=$(echo $x | awk '{print $5}')
	echo "$VIZINHO:$VizinhoPort:$SW_MASTER_PORT" >> HOLD.NS
	echo "|->$SW_MASTER:$SW_MASTER_PORT -> $VIZINHO:$VizinhoPort"
	echo "|"
done
unset IFS
echo "|_____"


API='http://zabbix/zabbix/api_jsonrpc.php'
ZABBIX_USER=""
ZABBIX_PASS=""


SW_MASTER=$1
NOME=$2

LARGURA="1347"
ALTURA="600"
LARGURA_P=$(expr 1347 / 2)
ALTURA_P=$(expr 600 / 4)
ALTURA_F=$(echo "$ALTURA_P * 1.2" | bc | awk -F\. '{print $1}')
RAND_LARG=$((RANDOM%$LARGURA_P+$ALTURA_F))
LARGURA_I="29"
#echo $RAND_LARG
#RAND_LABEL_LOCATION=$(shuf -e "0" "1" "2" "3")

authenticate()
{
    wget -O- -o /dev/null $API --header 'Content-Type: application/json-rpc' --post-data "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"user.login\",
        \"params\": {
                \"user\": \"$ZABBIX_USER\",
                \"password\": \"$ZABBIX_PASS\"},
        \"id\": 0}" | cut -d'"' -f8
}
AUTH=$(authenticate)

group_get() {

    wget -O- -o /dev/null $API --header 'Content-Type: application/json-rpc' --post-data "{
 
   \"jsonrpc\": \"2.0\",
    \"method\": \"hostgroup.get\",
    \"params\": {
        \"output\": \"extend\",
        \"filter\": {
            \"name\": [
                \"Discovery Network\"
            ]
        }
    },
    \"auth\": \"$AUTH\",
    \"id\": 1}" | awk -v RS=',"' -F\" '/^hostid/ {print $2}' | sed 's/"//g'
}

group_get
group_mk() {
    wget -O- -o /dev/null $API --header 'Content-Type: application/json-rpc' --post-data "{

    \"jsonrpc\": \"2.0\",
    \"method\": \"hostgroup.create\",
    \"params\": {
        \"name\": \"Discovery Network\"
    },
    \"auth\": \"$AUTH\",
    \"id\": 1}"
}


#GRPID=$(group_get | awk -v RS=',"' -F\" '/^hostid/ {print $2}' | sed 's/"//g')
#if [ -z "$GRPID" ]; then
#	group_mk
#fi


hostget() {
    wget -O- -o /dev/null $API --header 'Content-Type: application/json-rpc' --post-data "{

	\"jsonrpc\": \"2.0\",
	    \"method\": \"host.get\",
  	  \"params\": {
       	 \"output\": \"hostid\",
	\"selectInterfaces\": \"extend\",
       	 \"filter\": {
       	     \"host\": [
       	         \"$HOST\"
       	     ]
       	 }
    	},
   	 \"auth\": \"$AUTH\",
   	 \"id\": 1 }"
	
}


mkfilhos() {
seid=2
GIDS=$(cat HOLD.NS)
QNTD_GIDS=$(cat HOLD.NS | wc -l)
QNTD_GIDSL=$(echo $QNTD_GIDS)

#QNTD_GIDSL=`expr $QNTD_GIDS + 1`



for ITEM in `echo $GIDS`
do
        RAND_LABEL_LOCATION=$(shuf -e "0" "1" "2" "3" | head -n1)

        VIZINHO=$(echo $ITEM | awk -F: '{print $1}')
        VizinhoPort=$(echo $ITEM | awk -F:  '{print $2}')
        SW_MASTER_PORT=$(echo $ITEM | awk -F: '{print $3}')

        ALTURA_F=$(echo "$ALTURA_P * 1.5" | bc | awk -F. '{print $1}')
        if [ "$QNTD_GIDSL" -ne "$seid" ]; then
        echo -e "\t{"
        echo -e "\t\"selementid\": \"$seid\","
        echo -e "\t\"label_location\": \"$RAND_LABEL_LOCATION\","
        echo -e "\t\"x\": \"$LARGURA_I\","
        echo -e "\t\"y\": \"$ALTURA_F\","
        echo -e "\t\"elementid\": \"$HOSTID\","
        echo -e "\t\"elementtype\": 4,"
        echo -e "\t\"label\": \"$VIZINHO\","
        echo -e "\t\"iconid_off\": \"153\""
        echo -e "\t},"
        seid=`expr $seid + 1`
        LARGURA_I=`expr $LARGURA_I + 75`
                else
        echo -e "\t{"
        echo -e "\t\"selementid\": \"$seid\","
        echo -e "\t\"label_location\": \"$RAND_LABEL_LOCATION\","
        echo -e "\t\"x\": \"$LARGURA_I\","
        echo -e "\t\"y\": \"$ALTURA_F\","
        echo -e "\t\"label\": \"$VIZINHO\","
        echo -e "\t\"elementid\": \"$HOSTID\","
        echo -e "\t\"elementtype\": 4,"
        echo -e "\t\"iconid_off\": \"153\""
        echo -e "\t}"
        fi


done
}


mklinks() {

echo "\"links\": ["
seid=2
GIDS=$(cat HOLD.NS)
QNTD_GIDS=$(cat HOLD.NS | wc -l)
QNTD_GIDSL=$(echo $QNTD_GIDS)
#QNTD_GIDSL=`expr $QNTD_GIDS + 1`
for ITEM in `echo $GIDS`
do
        VIZINHO=$(echo $ITEM | awk -F: '{print $1}')
        VizinhoPort=$(echo $ITEM | awk -F: '{print $2}')
        SW_MASTER_PORT=$(echo $ITEM | awk -F: '{print $3}')

        if [ "$QNTD_GIDSL" -ne "$seid" ]; then
        echo -e "\t{"
        echo -e "\t\"label\": \"$SW_MASTER - $SW_MASTER_PORT -> $VIZINHO - $VizinhoPort\","
        echo -e "\t\"color\" : \"009900\","
        echo -e "\t\"drawtype\" : \"2\","
        echo -e "\t\"selementid1\": \"1\","
        echo -e "\t\"selementid2\": \"$seid\""
        echo -e "\t},"
        seid=`expr $seid + 1`
                else
        echo -e "\t{"
        echo -e "\t\"label\": \"$SW_MASTER - $SW_MASTER_PORT -> $VIZINHO - $VizinhoPort\","
        echo -e "\t\"color\" : \"009900\","
        echo -e "\t\"drawtype\" : \"2\","
        echo -e "\t\"selementid1\": \"1\","
        echo -e "\t\"selementid2\": \"$seid\""
        echo -e "\t}"
        echo    "]"
        fi
done
}


start() {
 wget -O- -o /dev/null $API --header 'Content-Type: application/json-rpc' --post-data "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"map.create\",
    \"params\": {
        \"name\": \"$NOME\",
        \"width\": $LARGURA,
        \"height\": $ALTURA,
        \"label_type\": \"0\",
        \"expand_macros\": \"1\",
        \"selements\": [
                {
                \"selementid\": \"1\",
                \"x\": \"$LARGURA_P\",
                \"y\": \"$ALTURA_P\",
                \"label\": \"{HOST.NAME}\",
                \"elementid\": \"10368\",
                \"elementtype\": 4,
                \"iconid_off\": \"97\"
                },
                $(mkfilhos)
                ],
               $(mklinks)
        },
    \"auth\": \"$AUTH\",
    \"id\": 1}"
}
start
echo

