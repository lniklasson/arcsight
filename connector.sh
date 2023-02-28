#!/bin/bash
#set -x
# Author: Lars Niklasson
# 2022-08-29
#
# Version 3.0
# Last changed by Lars Niklasson
#
#Who: Lars Niklasson
#What: Added more Raw checks
#When: 20230105
#Where: Little here and there
#Why: Better event monitoring, EPS not covering low EPS Connectors

### FUNCTIONS ###

function loadSettings() {
  CHECKMK="/opt/arcsight/connectors/$CONNECTOR/check-mk"
  if [[ ! -d $CHECKMK ]]; then
    mkdir $CHECKMK
  fi
  input="/opt/arcsight/connectors/$CONNECTOR/check-mk/settings.properties"
  if [[ -f $input ]]; then
    while read -r line
    do
      property="`echo $line | awk -F= '{ print $1 }'`"
      value="`echo $line | awk -F= '{ print $2 }'`"
      if [[ "$property" == "RawEventSuppressThreshold" ]]; then
        RawEventSuppressThreshold=$value
      elif [[ "$property" == "DisableRawEventsMonitoring" ]]; then
         if [[ $value == "True" ]]; then
           DisableRawEventsMonitoring=True
         else
           DisableRawEventsMonitoring=False
         fi
      elif [[ "$property" == "Disable" ]]; then
         Disable=$value
      elif [[ "$property" == "DisableRawEventsSLCThresholding" ]]; then
         DisableRawEventsSLCThresholding=$value
      else
         echo ALERT: found unknown setting in /opt/arcsight/connectors/$CONNECTOR/check-mk/settings.properties
      fi
    done < "$input"
  else
    # Creating default prop file
    echo RawEventSuppressThreshold=6 > $input
    RawEventSuppressThreshold=6
    # Moving from old to new conf using properties file instead of files as flags
    if [[ -f "/opt/arcsight/connectors/$CONNECTOR/DISABLE_MONITORING" ]]; then
      echo Disable=True >> $input
      Disable=True
      rm -f /opt/arcsight/connectors/$CONNECTOR/DISABLE_MONITORING
    else
      echo Disable=False >> $input
      Disable=False
    fi
    if [[ -f "/opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding" ]]; then
      echo DisableRawEventsSLCThresholding=True >> $input
      DisableRawEventsSLCThresholding=True
      rm -f /opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding
    else
      echo DisableRawEventsSLCThresholding=False >> $input
      DisableRawEventsSLCThresholding=False
    fi
  fi
  # If prop file exist but do not incl the Disable setting, adding it
  if [[ $Disable != "True" && $Disable != "False" ]]; then
    if [[ -f "/opt/arcsight/connectors/$CONNECTOR/DISABLE_MONITORING" ]]; then
      echo Disable=True >> $input
      Disable=True
      rm -f /opt/arcsight/connectors/$CONNECTOR/DISABLE_MONITORING
    else
      echo Disable=False >> $input
      Disable=False
    fi
  fi
  # If prop file exist but do not incl the Disable setting, adding it
  if [[ $DisableRawEventsSLCThresholding != "True" && $DisableRawEventsSLCThresholding != "False" ]]; then
    if [[ -f "/opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding" ]]; then
      echo DisableRawEventsSLCThresholding=True >> $input
      DisableRawEventsSLCThresholding=True
      rm -f /opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding
    else
      echo DisableRawEventsSLCThresholding=False >> $input
      DisableRawEventsSLCThresholding=False
    fi
  fi
  # If prop file exist but do not incl the Disable setting, adding it
  if [[ $DisableRawEventsMonitoring != "True" && $DisableRawEventsMonitoring != "False" ]]; then
    echo DisableRawEventsMonitoring=False >> $input
    DisableRawEventsMonitoring=False
  fi
}

function additionalChecks() {
  TIMESTAMP="`date +%Y%m%dT%H%M%SZ`"
  CONNECTORPATH="/opt/arcsight/connectors/$CONNECTOR/current/logs/"
  TIMESTAMPTOSEARCH="`date -d '2 minute ago' '+%Y-%m-%d %H:%M'`"
  #EPS=`grep Eps $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | awk -F= '{print $2}' | awk -F, '{print $1}'`
  #echo Grep Eps: $EPS >> /tmp/$CONNECTOR-$TIMESTAMP-stats.log
  connectorEPSIN=`grep "Queue Rate(SLC)" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | tr "," "\n" | grep "Queue Rate(SLC)" | awk -F= '{print $2}'`
  currentQueueDrop=`grep "Current Drop Count" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep "Current Drop Count" | awk -F= '{print $2}'`
  connectorEPSOUT=`grep "{C=" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | grep "ET=Up" | tail -1 | awk -F, '{print $7}' | awk -F= '{print $2}' | awk -F} '{print $1}'`
  connectorCache=`grep "{C=" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | grep "ET=Up" | tail -1 | awk -F, '{print $2}' | awk -F= '{print $2}'`
  #$CONNECTORPATH/../bin/arcsight agentcommand -c status | grep -i -E 'event|queue|count|sent|desc|throughput' | grep -v "^C\[" > /tmp/$CONNECTOR-$TIMESTAMP-agentcommand.log

  if [[ $connectorCache -gt 99 ]];then
    #WARN
    echo 0 ArcSight_connectorCache_$CONNECTOR connectorCache=$connectorCache\|connectorEPSIN=$connectorEPSIN\|connectorEPSOUT=$connectorEPSOUT Cache: $connectorCache, EPS IN: $connectorEPSIN, EPS OUT: $connectorEPSOUT ---
  else
    echo 0 ArcSight_connectorCache_$CONNECTOR connectorCache=$connectorCache\|connectorEPSIN=$connectorEPSIN\|connectorEPSOUT=$connectorEPSOUT Cache: $connectorCache, EPS IN: $connectorEPSIN, EPS OUT: $connectorEPSOUT ---
  fi

  if [[ $currentQueueDrop -gt 0 ]];then
    #WARN
    echo 0 ArcSight_QUEUE_currentDrop_$CONNECTOR currentQueueDrop=$currentQueueDrop Current Queue Drop: $currentQueueDrop ---
  else
    echo 0 ArcSight_QUEUE_currentDrop_$CONNECTOR currentQueueDrop=$currentQueueDrop Current Queue Drop: $currentQueueDrop ---
  fi

  FirstEventProcessed=`grep "First Event Processed" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep "First Event Processed" | awk -F= '{print $2}'`
  echo 0 ArcSight_FirstEventProcessed_$CONNECTOR - First Event Processed: $FirstEventProcessed

  agentVersion=`grep "Agent Version" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep "Agent Version" | awk -F= '{print $2}'`
  ParserAUPVersion=`grep "Parser AUP Version" $CONNECTORPATH/agent.log | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep "Parser AUP Version" | awk -F= '{print $2}'`
  echo 0 ArcSight_agentVersion_$CONNECTOR - Agent Version: $agentVersion, Parser AUP Version: $ParserAUPVersion

}


function rawEventCheck() {
  TIMESTAMP="`date +%Y%m%dT%H%M%SZ`"
  CONNECTORPATH="/opt/arcsight/connectors/$CONNECTOR/current/logs/"
  TIMESTAMPTOSEARCH="`date -d '2 minute ago' '+%Y-%m-%d %H:%M'`"

  RawEventCount="`grep -h '{AddrBasedSysZonePopEvents=' $CONNECTORPATH/agent.log $CONNECTORPATH/agent.log.1 | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep RawEventCount | awk -F= '{print $2}'`"
  RawEventLen="`grep -h '{AddrBasedSysZonePopEvents=' $CONNECTORPATH/agent.log $CONNECTORPATH/agent.log.1 | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep RawEventLen | awk -F= '{print $2}'`"
  RawEventPreAggregatedCount="`grep -h '{AddrBasedSysZonePopEvents=' $CONNECTORPATH/agent.log $CONNECTORPATH/agent.log.1 | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep RawEventPreAggregatedCount | awk -F= '{print $2}'`"
  if [[ $RawEventPreAggregatedCount == "" ]]; then
    RawEventPreAggregatedCount=0
  fi
  # Suppressing should be use if file exist and do not have value -1
  #if [[ -f $CHECKMK/RawEventSuppressThreshold ]]; then
  #  # If the first time executing
  #  if [[ -f $CHECKMK/RawEventSuppress ]]; then
  #    RawEventSuppress="`cat $CHECKMK/RawEventSuppress`"
  #  else
  #    RawEventSuppress=0
  #  fi
  #  RawEventSuppressThreshold="`cat $CHECKMK/RawEventSuppressThreshold`"
  #else
  #  # default suppression to 6 (6 x 10 min = 1 hour)
  #  RawEventSuppressThreshold=6
  #  if [[ -f $CHECKMK/RawEventSuppress ]]; then
  #    RawEventSuppress="`cat $CHECKMK/RawEventSuppress`"
  #  else
  #    RawEventSuppress=0
  #  fi
  #fi
  if [[ -f $CHECKMK/RawEventSuppress ]]; then
    RawEventSuppress="`cat $CHECKMK/RawEventSuppress`"
  else
    RawEventSuppress=0
  fi

  if [[ -f $CHECKMK/RawEventPreAggregatedCount.tmp ]]; then
    RawEventPreAggregatedCountLast="`cat $CHECKMK/RawEventPreAggregatedCount.tmp`"
    echo $RawEventPreAggregatedCount > $CHECKMK/RawEventPreAggregatedCount.tmp
  else
    RawEventPreAggregatedCountLast=0
    echo $RawEventPreAggregatedCount > $CHECKMK/RawEventPreAggregatedCount.tmp
  fi
  if [[ $RawEventPreAggregatedCount -gt 0 ]]; then
    RawEventAvgSize="`expr $RawEventLen \/ $RawEventPreAggregatedCount`"
  else
    RawEventAvgSize=0
  fi
  FirstGlobaleventProcessed="`grep -h '{AddrBasedSysZonePopEvents=' $CONNECTORPATH/agent.log $CONNECTORPATH/agent.log.1 | grep "$TIMESTAMPTOSEARCH" | tail -1 | tr "," "\n" | grep "First Global event Processed" | awk -F= '{print $2}'`"
  FirstGlobaleventProcessedEpoch="`date -d "$FirstGlobaleventProcessed" '+%s'`"
  NowEpoch="`date '+%s'`"
  SecRunning="`expr $NowEpoch - $FirstGlobaleventProcessedEpoch`"
  if [[ $SecRunning -gt 0 ]]; then
    AvgEPSSinceStart="`echo $RawEventPreAggregatedCount \/ $SecRunning | bc -l | cut -b 1-6`"
  else
    AvgEPSSinceStart=0
  fi

  RawEventsSLC="`expr $RawEventPreAggregatedCount - $RawEventPreAggregatedCountLast`"

  ENABLE_ECHO=0
  if [[ $ENABLE_ECHO -ne 0 ]]; then
    echo RawEventPreAggregatedCount=$RawEventPreAggregatedCount
    echo RawEventPreAggregatedCountLast=$RawEventPreAggregatedCountLast
    echo Raw Events SLC: $RawEventsSLC
    echo RawEventCount=$RawEventCount
    echo RawEventLen=$RawEventLen
    echo RawEventAvgSize=$RawEventAvgSize
    echo FirstGlobaleventProcessed=$FirstGlobaleventProcessed
    echo FirstGlobaleventProcessedEpoch=$FirstGlobaleventProcessedEpoch
    echo NowEpoch=$NowEpoch
    echo SecRunning=$SecRunning
    echo AvgEPSSinceStart=$AvgEPSSinceStart
    echo See $CHECKMK/$TIMESTAMP- ....
  fi

  if [[ $RawEventsSLC -lt 0 ]]; then
    $RawEventsSLC=0
  fi

  # Remove remark to print out disbaling file to be cretaed with touch
  #echo /opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding

  #if [[ -f /opt/arcsight/connectors/$CONNECTOR/check-mk/DISABLE_RawEventsSLC_Thresholding ]]; then
  if [[ $DisableRawEventsSLCThresholding == "True" ]]; then
    echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
      RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
      Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(thresholding disabled\) ---
    echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
      RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
      Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(thresholding disabled\) --- > $RawEventsSLCLastMessage
  elif [[ $RawEventSuppressThreshold -ne -1 ]]; then
    # Suppressing in use
    if [[ $RawEventSuppress -ge $RawEventSuppressThreshold ]]; then
      # Suppressing passed
      #if [[ $RawEventsSLC -gt 10000 ]]; then
      if [[ $RawEventsSLC -gt 0 ]]; then
        # Reset suppress
        RawEventSuppress=0
        echo 0 > $CHECKMK/RawEventSuppress
        echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression reset: $RawEventSuppress/$RawEventSuppressThreshold\) ---
        echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression reset: $RawEventSuppress/$RawEventSuppressThreshold\) --- > $RawEventsSLCLastMessage
      else
        #WARN
        echo 1 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression ended: $RawEventSuppress/$RawEventSuppressThreshold\) ---
        echo 1 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression ended: $RawEventSuppress/$RawEventSuppressThreshold\) --- > $RawEventsSLCLastMessage
      fi
    else
      # Suppressing in use and active
      #if [[ $RawEventsSLC -gt 10000 ]]; then
      if [[ $RawEventsSLC -gt 0 ]]; then
        if [[ $RawEventSuppress -eq 0 ]]; then
          echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
            RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
            Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(no suppression\) ---
          echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
            RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
            Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(no suppression\) --- > $RawEventsSLCLastMessage
        else
          echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
            RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
            Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression reseting: $RawEventSuppress/$RawEventSuppressThreshold\) ---
          echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
            RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
            Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression reseting: $RawEventSuppress/$RawEventSuppressThreshold\) --- > $RawEventsSLCLastMessage
        fi
        # Reset suppress
        echo 0 > $CHECKMK/RawEventSuppress
        RawEventSuppress=0
      else
        RawEventSuppress=$(($RawEventSuppress + 1))
        echo $RawEventSuppress > $CHECKMK/RawEventSuppress
        #WARN
        echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression ongoing: $RawEventSuppress/$RawEventSuppressThreshold\) ---
        echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
          RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
          Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC \(suppression ongoing: $RawEventSuppress/$RawEventSuppressThreshold\) --- > $RawEventsSLCLastMessage
      fi
    fi
  else
    if [[ $RawEventsSLC -gt 0 ]]; then
      echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
        RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
        Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC ---
      echo 0 ArcSight_RawEventsSLC_$CONNECTOR \
        RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
        Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC --- > $RawEventsSLCLastMessage
    else
      #WARN
      echo 1 ArcSight_RawEventsSLC_$CONNECTOR \
        RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
        Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC ---
      echo 1 ArcSight_RawEventsSLC_$CONNECTOR \
        RawEventAvgSize=$RawEventAvgSize\|RawEventsSLC=$RawEventsSLC\|AvgEPSSinceStart=$AvgEPSSinceStart\|RawEventPreAggregatedCount=$RawEventPreAggregatedCount \
        Raw Events SLC \(since last check, every 10th minute\): $RawEventsSLC --- > $RawEventsSLCLastMessage
    fi
  fi
}

function StartingConnector() {
  DATETIMEONEHOURBACK=`date "+%Y/%m/%d %H" -d '1 hour ago'`
  DATETIMETHISHOUR=`date "+%Y/%m/%d %H" -d '1 hour ago'`
  # Removed star
  restarts_last_two_hours="`grep -E "$DATETIMEONEHOURBACK|$DATETIMETHISHOUR" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | grep 'Starting \[Arcsight SmartAgent\]' | wc -l`"
  if [ $restarts_last_two_hours -ge 2 ]; then
    echo 0 ArcSight_RESTARTS_$CONNECTOR Restarts=$restarts_last_two_hours More than one restarts within the last 1-2 hours: $restarts_last_two_hours
  elif [ $restarts_last_two_hours -eq 1 ]; then
    echo 0 ArcSight_RESTARTS_$CONNECTOR Restarts=$restarts_last_two_hours One restart within the last 1-2 hours: $restarts_last_two_hours
  else
    echo 0 ArcSight_RESTARTS_$CONNECTOR Restarts=$restarts_last_two_hours No restarts within the last 1-2 hours: $restarts_last_two_hours
  fi
}

function Memory_Usage() {
  # Removed star
  Memory_Usage_Max="`grep "Memory Usage" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep "$two_min_ago" | awk '{ print $9 }' | rev | cut -c3- | rev`"
  Memory_Usage="`grep "Memory Usage" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep "$two_min_ago" | awk '{ print $6 }' | rev | cut -c3- | rev`"
  if [ "$Memory_Usage_Max" == "" ]; then
    # Removed star
    ISYELLOW=`grep 'Memory has reached yellow zone' /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep "$two_min_ago" | wc -l`
    ISRED=`grep 'Memory usage in red zone after garbage collection' /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep '$two_min_ago' | wc -l`
    if [ $ISRED != 0 ]; then
      echo 1 ArcSight_MEM_$CONNECTOR Memory_Usage_Procent=0\|Memory_Usage=0\|Memory_Usage_Max=0 Memory usage in red zone after garbage collection: $ISRED ---
    elif [ $ISYELLOW != 0 ]; then
      echo 0 ArcSight_MEM_$CONNECTOR Memory_Usage_Procent=0\|Memory_Usage=0\|Memory_Usage_Max=0 Memory has reached yellow zone. Number of line found last minute: $ISYELLOW ---
    else
      echo 0 ArcSight_MEM_$CONNECTOR Memory_Usage_Procent=0\|Memory_Usage=0\|Memory_Usage_Max=0 No data
    fi
  else
    Memory_Usage_Procent="`echo $(( ($Memory_Usage*100)/$Memory_Usage_Max ))`"
    if [ $Memory_Usage_Procent -lt 98 ]; then
      echo 0 ArcSight_MEM_$CONNECTOR Memory_Usage_Procent=$Memory_Usage_Procent\|Memory_Usage=$Memory_Usage\|Memory_Usage_Max=$Memory_Usage_Max \
        Memory usage in procent: $Memory_Usage_Procent, GB: $Memory_Usage, Max GB: $Memory_Usage_Max ---
    else
      #Change severity
      echo 0 ArcSight_MEM_$CONNECTOR Memory_Usage_Procent=$Memory_Usage_Procent\|Memory_Usage=$Memory_Usage\|Memory_Usage_Max=$Memory_Usage_Max \
        Memory usage in procent: $Memory_Usage_Procent, GB: $Memory_Usage, Max GB: $Memory_Usage_Max ---
    fi
  fi
}

function ConnectorQueue() {
  TEMPFILEQUEUE=/tmp/`echo $(date +%s%N | cut -b10-19)`_agent.log.temp1
  # Removed star
  grep 'Custom Filtering' /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep "`date -d '2 minute ago' '+%Y-%m-%d %H:%M'`" | tr "," "\n" | \
    grep -E 'Events Filtered Out|Events Processed|Events/Sec|Queue|device count|event count|event size|activeThreadCount' > $TEMPFILEQUEUE
  QueueDropCount=`grep 'Queue Drop Count=' $TEMPFILEQUEUE | awk -F= '{ print $2}'`
  QueueRate=`grep 'Queue Rate=' $TEMPFILEQUEUE | awk -F= '{ print $2}'`
  QueueRateSLC=`grep 'Queue Rate(SLC)=' $TEMPFILEQUEUE | awk -F= '{ print $2}'`
  if [ "$QueueDropCount" == "" ]; then
    echo 0 ArcSight_QUEUE_STATS_$CONNECTOR QueueDropCount=0\|QueueRate=0\|QueueRateSLC=0 No data
  else
    if [ ${QueueDropCount/.*} -eq 0 ]; then
      echo 0 ArcSight_QUEUE_STATS_$CONNECTOR QueueDropCount=$QueueDropCount\|QueueRate=$QueueRate\|QueueRateSLC=$QueueRateSLC \
        Queue Drop Count = $QueueDropCount, Queue Rate = $QueueRate, Queue Rate SLC = $QueueRateSLC
    else
      echo 0 ArcSight_QUEUE_STATS_$CONNECTOR QueueDropCount=$QueueDropCount\|QueueRate=$QueueRate\|QueueRateSLC=$QueueRateSLC \
        Queue Drop Count = $QueueDropCount, Queue Rate = $QueueRate, Queue Rate SLC = $QueueRateSLC
    fi
  fi
  filequeuemaxfilecount=`grep filequeuemaxfilecount /opt/arcsight/connectors/$CONNECTOR/current/user/agent/agent.properties | awk -F\= '{ print $2} '`
  if [ "$filequeuemaxfilecount" == "" ]; then
    filequeuemaxfilecount=100
  fi
  filequeuemaxfilecount_90_procent=`echo $(( $filequeuemaxfilecount*90/100 ))`
  IS_SYSLOG_CONNECTOR=0
  grep "type=syslog" /opt/arcsight/connectors/$CONNECTOR/current/user/agent/agent.properties > /dev/null
  if [ $? == 0 ]; then
    IS_SYSLOG_CONNECTOR=1
    ls -ltr /opt/arcsight/connectors/$CONNECTOR/current/user/agent/agentdata/*_queue.syslogd* 2>/dev/null > /tmp/$CONNECTOR.syslog.queue.tmp
    QUEUE=`wc -l /tmp/$CONNECTOR.syslog.queue.tmp | cut -d " " -f 1`
    if [ -z $QUEUE ]; then
      QUEUE=0
    fi
    if [ $QUEUE -lt $filequeuemaxfilecount_90_procent ]; then
      echo 0 ArcSight_QUEUE_$CONNECTOR QUEUE=$QUEUE Number of syslog queue files: $QUEUE, Max: $filequeuemaxfilecount, Threshold: $filequeuemaxfilecount_90_procent
    else
      echo 1 ArcSight_QUEUE_$CONNECTOR QUEUE=$QUEUE Number of syslog queue files is high: $QUEUE, Max: $filequeuemaxfilecount, Threshold: $filequeuemaxfilecount_90_procent
    fi
  fi
  rm -f $TEMPFILEQUEUE
}

function CheckConnectorEvents() {
  DOSProtector_in_agent_log_current_hour="`grep -E "$current_hour|$last_hour" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | \
                                             grep -E 'ERROR.*com.arcsight.agent.loadable._DOSProtector' | wc -l`"
  #echo DOSProtector_in_agent_log_current_hour: $DOSProtector_in_agent_log_current_hour
  Connector_Properties_Override_Version_Mismatch="`grep -E "$current_hour|$last_hour" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | \
                                                     grep 'Connector_Properties_Override_Version_Mismatch' | wc -l`"
  Cannot_parse_raw_event_current_hour="`grep -E "$current_hour|$last_hour" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | grep 'Cannot parse raw event' | wc -l`"
  if [ $Cannot_parse_raw_event_current_hour == "" ];then
    Cannot_parse_raw_event_current_hour=0
  fi
  ERROR_in_agent_log_current_hour="`grep -E "$current_hour|$last_hour" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | grep '\]\[ERROR\]\[' | wc -l`"
  ERRORLINE="`grep ERROR /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | tail -1`"
  ERROR_AREA="`echo $ERRORLINE | awk -F\[ '{ print $5}' | awk -F\] '{ print $1}'`"
  ERROR_MSG="`echo $ERRORLINE | awk -F\] '{ print $5 $6}' | cut -c2-31`"
  ERROR_LAST_TIME="`echo $ERRORLINE | awk -F\] '{ print $1}' | awk  '{ print $2}' | awk -F, '{ print $1}'`"
  if [ $ERROR_in_agent_log_current_hour == "" ];then
    ERROR_in_agent_log_current_hour=0
  fi
  if [ $ERROR_in_agent_log_current_hour -eq 0 ]; then
    echo 0 ArcSight_ERROR_$CONNECTOR ERROR_in_agent_log_current_hour=0\|Cannot_parse_raw_event_current_hour=0\|DOSProtector_in_agent_log_current_hour=0\|Connector_Properties_Override_Version_Mismatch=0 No ERROR message seen
  else
    #Change severity
    echo 0 ArcSight_ERROR_$CONNECTOR ERROR_in_agent_log_current_hour=$ERROR_in_agent_log_current_hour\|Cannot_parse_raw_event_current_hour=$Cannot_parse_raw_event_current_hour\|DOSProtector_in_agent_log_current_hour=$DOSProtector_in_agent_log_current_hour\|Connector_Properties_Override_Version_Mismatch=$Connector_Properties_Override_Version_Mismatch \
      Latest ERROR at $ERROR_LAST_TIME: $ERROR_AREA/$ERROR_MSG... More info: /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log
  fi
  FATAL_in_agent_log_current_hour="`grep -E "$current_hour|$last_hour" /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | grep '\]\[FATAL\]\[' | wc -l`"
  FATALLINE="`grep FATAL /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | tail -1`"
  FATAL_AREA="`echo $FATALLINE | awk -F\[ '{ print $5}' | awk -F\] '{ print $1}'`"
  FATAL_MSG="`echo $FATALLINE | awk -F\] '{ print $5 $6}' | cut -c2-31`"
  FATAL_LAST_TIME="`echo $FATALLINE | awk -F\] '{ print $1}' | awk  '{ print $2}' | awk -F, '{ print $1}'`"
  if [ $FATAL_in_agent_log_current_hour == "" ];then
    FATAL_in_agent_log_current_hour=0
  fi
  if [ $FATAL_in_agent_log_current_hour -eq 0 ]; then
    echo 0 ArcSight_FATAL_$CONNECTOR FATAL_in_agent_log_current_hour=0 No FATAL message seen
  else
    #Change severity
    echo 0 ArcSight_FATAL_$CONNECTOR FATAL_in_agent_log_current_hour=$FATAL_in_agent_log_current_hour Latest FATAL at $FATAL_LAST_TIME: $FATAL_AREA/$FATAL_MSG... More info: /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log
  fi
}

function processSingleAlert() {
  processSingleAlert_LAST_MIN="`date \"+%Y-%m-%d %H:%M\" --date=\"1 minutes ago\"`"
  # Removed star
  processSingleAlert_LOGLINE="`grep processSingleAlert /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep \"$processSingleAlert_LAST_MIN\" | tail -1`"
  processSingleAlert_MESSAGE="`echo $processSingleAlert_LOGLINE | awk -F 'processSingleAlert] ' '{print $2}'`"
  processSingleAlert_DATETIME="`echo $processSingleAlert_LOGLINE | awk -F 'processSingleAlert] ' '{print $1}' | cut -d, -f1 | cut -d\[ -f2`"

  if [[ $processSingleAlert_LOGLINE != "" ]]; then
    #echo $MESSAGE \($DATETIME\)
    echo 0 ArcSight_processSingleAlert_$CONNECTOR processSingleAlert=1 $processSingleAlert_MESSAGE \($processSingleAlert_DATETIME\)
  else
    echo 0 ArcSight_processSingleAlert_$CONNECTOR processSingleAlert=0 No processSingleAlert messaged found
  fi
}

#function CheckConnectorsEventprocessed() {
#  TEMPFILEEVENTPROC=/tmp/`echo $(date +%s%N | cut -b10-19)`_agent.log.temp1
#  grep 'Agent Type' /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log* | grep "`date -d '1 minute ago' '+%Y-%m-%d %H:%M'`" | tr "," "\n" | \
#    grep -E 'Last Event Processed|Events Processed' > $TEMPFILEEVENTPROC
#  EventsProcessed=`grep 'Events Processed=' $TEMPFILEEVENTPROC | awk -F= '{ print $2}'`
#  EventsProcessedSLC=`grep 'Events Processed(SLC)=' $TEMPFILEEVENTPROC | awk -F= '{ print $2}'`
#  LastEventProcessed=`grep 'Last Event Processed=' $TEMPFILEEVENTPROC | awk -F= '{ print $2}'`
#  graph_string1="Events_Processed_SLC=$EventsProcessedSLC"
#  if [[ -z $EventsProcessedSLC ]]; then
#    echo 0 ArcSight_EventsProcessedSLC_$CONNECTOR Events_Processed_SLC=0 EventsProcessed\(SLC\) is NULL
#  else
#    if [ $EventsProcessedSLC -eq 0 ]; then
#      echo 0 ArcSight_EventsProcessedSLC_$CONNECTOR $graph_string1 Last Event Processed: $LastEventProcessed. Connector have not processed any event last minute
#    else
#      echo 0 ArcSight_EventsProcessedSLC_$CONNECTOR $graph_string1 Last Event Processed: $LastEventProcessed. EventsProcessed\(SLC\): $EventsProcessedSLC
#    fi
#  fi
#  rm -f $TEMPFILEEVENTPROC
#}

#############
### START ###
#############

# Param 1: now
# will trigger a RawEvents calculation directly instrad of only every X0 minute
# Param 2: xxx
# will filter the Connectors to be analyized with xxx
# They cannot change places!

### COMMON VARIBLES ###
DATETIME=`date "+%Y/%m/%d %H:%M" -d '1 minute ago'`
DATETIME_MINUS_TWO_MINUTES=`date "+%Y/%m/%d %H:%M" -d '2 minute ago'`
TOTAL_EPS_IN=0
TOTAL_EVT_IN=0
TEMPFILE=/tmp/`echo $(date +%s%N | cut -b10-19)`_agent.log.temp1
current_hour="`date '+%Y-%m-%d %H'`"
last_hour="`date -d '1 hour ago' '+%Y-%m-%d %H'`"
two_min_ago="`date -d '2 minute ago' '+%Y-%m-%d %H:%M'`"

#CONNECTORS=`ls /opt/arcsight/connectors | grep arcconlx12_egad_tls_esm02_02`

if [[ "$2" != "" ]]; then
  CONNECTORS=`ls /opt/arcsight/connectors | grep $2`
else
  CONNECTORS=`ls /opt/arcsight/connectors`
fi

for CONNECTOR in $CONNECTORS; do
  loadSettings
  #if [[ -f "/opt/arcsight/connectors/$CONNECTOR/DISABLE_MONITORING" ]]; then
  #  continue
  #fi
  if [[ $Disable == "True" ]]; then
    continue
  fi
  StartingConnector
  Memory_Usage $CONNECTOR
  ConnectorQueue $CONNECTOR
  CheckConnectorEvents $CONNECTOR
  processSingleAlert $CONNECTOR
#  CheckConnectorsEventprocessed $CONNECTOR
  # Removed star
  grep 'Custom Filtering' /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.log | grep "`date -d '2 minute ago' '+%Y-%m-%d %H:%M'`" | tr "," "\n" | \
    grep -E 'Events Filtered Out|Events Processed|Events/Sec|Queue|device count|event count|event size|activeThreadCount' > $TEMPFILE
  EventsProcessed=`grep 'Events Processed=' $TEMPFILE | awk -F= '{ print $2}'`
  EventsProcessedSLC=`grep 'Events Processed(SLC)=' $TEMPFILE | awk -F= '{ print $2}'`
  #echo EventsProcessedSLC for $CONNECTOR: $EventsProcessedSLC
  CustomFilteredOut=`grep 'Custom Filtering: Events Filtered Out=' $TEMPFILE | awk -F= '{ print $2}'`
  if [ "$CustomFilteredOut" == "" ]; then
    CustomFilteredOut_Procent=0
  elif [ $CustomFilteredOut -eq 0 ]; then
    CustomFilteredOut_Procent=0
  elif [ $EventsProcessed == "" ]; then
    CustomFilteredOut_Procent=0
  else
    CustomFilteredOut_Procent=`echo $(( ($CustomFilteredOut*100)/$EventsProcessed ))`
  fi
  EventsSec=`grep 'Events/Sec=' $TEMPFILE | awk -F= '{ print $2}'`
  EventsSecSLC=`grep 'Events/Sec(SLC)=' $TEMPFILE | awk -F= '{ print $2}'`
  Trackingdevicecount=`grep 'Tracking: device count=' $TEMPFILE | awk -F= '{ print $2}'`
  Trackingeventcount=`grep 'Tracking: event count=' $TEMPFILE | awk -F= '{ print $2}'`
  Trackingeventsize=`grep 'Tracking: event size=' $TEMPFILE | awk -F= '{ print $2}'`
  activeThreadCount=`grep 'activeThreadCount=' $TEMPFILE | awk -F= '{ print $2}'`
  graph_string1="CustomFilteredOut=$CustomFilteredOut\|CustomFilteredOut_Procent=$CustomFilteredOut_Procent\|Events_Processed_SLC=$EventsProcessedSLC\|Events_Sec=$EventsSec\|Events_Sec_SLC=$EventsSecSLC"
  graph_string1="\|$graph_string1\|Tracking_device_count=$Trackingdevicecount\|Tracking_event_count=$Trackingeventcount\|Tracking_event_size=$Trackingeventsize\|active_Thread_Count=$activeThreadCount"
  #echo $graph_string1
  # Custom Filtering: Events Filtered Out=0
  # Events Processed=1973940
  # Events Processed(SLC)=99
  # Events/Sec=3.313113884618225
  # Events/Sec(SLC)=1.65
  # Queue Drop Count=0.0
  # Queue Rate=3.0446177265838337
  # Queue Rate(SLC)=0.05
  # Tracking: device count=792
  # Tracking: event count=121103208
  # Tracking: event size=58158486150
  # activeThreadCount=231

#  echo ====== CONNECTOR WHICH IS CHECKED: $CONNECTOR ======
  EVT_IN_LOG_ROWS=0
  # Removed star
  EVT_IN_LOG_ROWS=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | grep "$DATETIME" | wc -l`
  if [ -z $EVT_IN_LOG_ROWS ]; then
    # Removed star
    EVT_IN_LOG_ROWS=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | grep "$DATETIME_MINUS_TWO_MINUTES" | wc -l`
  fi
  # Removed star
  EPS_IN=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | \
    grep "$DATETIME" | grep Eps | awk {' print $17'} | awk -F= {' print $2'} | awk -F. {' print $1'}`
  # Removed star
  EVT_IN=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | \
    grep "$DATETIME" | grep Eps | awk {' print $18'} | awk -F= {' print $2'} | awk -F. {' print $1'} | sed 's/}//'`
  if [ -z $EPS_IN ]; then
    # Removed star
    EPS_IN=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | \
      grep "$DATETIME_MINUS_TWO_MINUTES" | grep Eps | awk {' print $17'} | awk -F= {' print $2'} | awk -F. {' print $1'}`
    # Removed star
    EVT_IN=`cat /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log | \
      grep "$DATETIME_MINUS_TWO_MINUTES" | grep Eps | awk {' print $18'} | awk -F= {' print $2'} | awk -F. {' print $1'} | sed 's/}//'`
  fi
  if [ -z $EPS_IN ]; then
    EPS_IN=0
  fi
  if [ -z $EVT_IN ]; then
    EVT_IN=0
  fi


  connectorconf="/usr/lib/check_mk_agent/plugins/connectors_eps.conf"
  if  [ ! -f $connectorconf ]; then
        touch $connectorconf
  fi

  Real_EPS=$EPS_IN
  if grep -q $CONNECTOR $connectorconf ; then
        TRAILCONNECTOR=true
        MINUTES=$(cat $connectorconf | grep $CONNECTOR | awk -F ':' '{print $2}')
        TEMPFILEEPS="/tmp/totaleps_${CONNECTOR}"
        # Add EPS to the end of the file
        echo $EPS_IN >> $TEMPFILEEPS
        # Remove the top line of the file if there are more than the value in MINUTES
        sed -i -e :a -e "\$q;N;${MINUTES},\$D;ba"  $TEMPFILEEPS
        EPSoverTime=0
        for line in $(cat $TEMPFILEEPS); do
                # Done care of EPS of 1
#                if [ $line -ne 1 ]; then
#                    EPSoverTime=$(( $EPSoverTime + $line  ))
#                fi
                EPSoverTime=$(( $EPSoverTime + $line  ))
        done
        if [ $EPSoverTime -ne 0 ]; then
                EPS_IN="2"
                EVT_IN="2"
        fi
  else
        TRAILCONNECTOR=false
        MINUTES=30
        TEMPFILEEPS="/tmp/totaleps_${CONNECTOR}"
        # Add EPS to the end of the file
        echo $EPS_IN >> $TEMPFILEEPS
        # Remove the top line of the file if there are more than the value in MINUTES
        sed -i -e :a -e "\$q;N;${MINUTES},\$D;ba"  $TEMPFILEEPS
        EPSoverTime=0
        for line in $(cat $TEMPFILEEPS); do
                # Done care of EPS of 1
#                if [ $line -ne 1 ]; then
#                    EPSoverTime=$(( $EPSoverTime + $line  ))
#                fi
                EPSoverTime=$(( $EPSoverTime + $line  ))
        done
        if [ $EPSoverTime -ne 0 ]; then
                EPS_IN="2"
                EVT_IN="2"
        fi

  fi
#  echo /opt/arcsight/connectors/$CONNECTOR/current/logs/agent.out.wrapper.log
#  echo $DATETIME
#  echo EPS_IN: $EPS_IN EVT_IN: $EVT_IN
  if [ -z $EPS_IN ]; then
    if [ $EVT_IN_LOG_ROWS -eq 0 ]; then
      echo 1 ArcSight_EPS_$CONNECTOR EPS_IN=0\|EVT_IN=0$graph_string1 Connector is down ---
    else
      echo 0 ArcSight_EPS_$CONNECTOR EPS_IN=0\|EVT_IN=0$graph_string1 No data available ---
    fi
  elif [ $EPS_IN -eq 0 ]; then
    if [ -f /opt/arcsight/connectors/$CONNECTOR/24H_THRESHOLDING ]; then
      echo 0 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EPS IN is 0 ---
    else
      # If the EPS is 0 and is is not taged with 24THRESHOLDING, create a critical alert
      echo 1 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EPS IN is 0 ---
    fi
  elif [ $EPS_IN -eq 1 ]; then
    if [ -f /opt/arcsight/connectors/$CONNECTOR/NEVER1EPS ]; then
      # If the EPS is 1 and is taged with NEVER1EPS, create a critical alert
      echo 1 ArcSight_EPS_$CONNECTOR EPS_IN=0\|EVT_IN=0$graph_string1 EPS IN is 0 ---
    else
      echo 0 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EPS IN is 0 ---
    fi
  elif [ $EVT_IN -eq 0 ]; then
    if [ -f /opt/arcsight/connectors/$CONNECTOR/24H_THRESHOLDING ]; then
      echo 0 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EVT IN is 0 ---
    else
      echo 1 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EVT IN is 0 ---
    fi
  else
      echo 0 ArcSight_EPS_$CONNECTOR EPS_IN=$Real_EPS\|EVT_IN=$EVT_IN$graph_string1 EPS IN: $Real_EPS, EVT IN: $EVT_IN ---
    #echo $TOTAL_EPS_IN + $Real_EPS
    #echo $TOTAL_EVT_IN + $EVT_IN
    TOTAL_EPS_IN=`expr $TOTAL_EPS_IN + $Real_EPS`
    TOTAL_EVT_IN=`expr $TOTAL_EVT_IN + $EVT_IN`
  fi

  additionalChecks

  if [[ ! $DisableRawEventsMonitoring == "True" ]]; then
    RawEventsSLCLastMessage="$CHECKMK/ArcSight_RawEventsSLC-last.message"
    if [[ -f $RawEventsSLCLastMessage ]]; then
      if [[ "$1" == "now" ]]; then
        # if now exist as params to script, run always
        rawEventCheck
      elif [[ "`date +%M | cut -b2`" -ne 0 ]]; then
        # skip if not X0
        cat $RawEventsSLCLastMessage
        continue
      else
        # Run this check only every 10 min, X0
        rawEventCheck
      fi
    else
      # Run because this is the first time
      rawEventCheck
    fi
  fi
done

if [ -z $TOTAL_EPS_IN ]; then
  echo 0 ArcSight_EPS_TOTAL TOTAL_EPS_IN=0\|TOTAL_EVT_IN=0 No data available ---
elif [ $TOTAL_EPS_IN -eq 0 ]; then
  echo 0 ArcSight_EPS_TOTAL TOTAL_EPS_IN=$TOTAL_EPS_IN\|TOTAL_EVT_IN=$TOTAL_EVT_IN TOTAL EPS IN is 0 ---
elif [ $TOTAL_EVT_IN -eq 0 ]; then
  echo 0 ArcSight_EPS_TOTAL TOTAL_EPS_IN=$TOTAL_EPS_IN\|TOTAL_EVT_IN=$TOTAL_EVT_IN TOTAL EVT IN is 0 ---
else
  echo 0 ArcSight_EPS_TOTAL TOTAL_EPS_IN=$TOTAL_EPS_IN\|TOTAL_EVT_IN=$TOTAL_EVT_IN TOTAL EPS IN: $TOTAL_EPS_IN and TOTAL EVT IN: $TOTAL_EVT_IN ---
fi

rm -f $TEMPFILE




