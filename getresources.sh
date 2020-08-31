#!/bin/bash
# testing container resources

# Instructions #
# to be used on jobs that are using this orb to store memory usage with the store_usage_allocation command

# variables 
CIRCLE_TOKEN=<CircleCI API Token>
CIRCLE_PROJECT_REPONAME=<Repository>
CIRCLE_PROJECT_USERNAME=<Project>
MAX_ACCEPTABLE=<max acceptable usage>
MIN_ACCEPTABLE=<min acceptable usage>

## function definitions - start ##

#install JQ
installJQ () {
   if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
   $SUDO apt-get update && $SUDO apt-get install -y jq
}

#get pipeline and store workflow IDs https://circleci.com/docs/api/v2/#get-a-pipeline-39-s-workflows
getWorkflowIds () {
  PIPELINE_API_CALL=`curl -u ${CIRCLE_TOKEN}: --header "Content-Type: application/json" -X GET https://circleci.com/api/v2/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/pipeline`

  echo $PIPELINE_API_CALL | jq .items | jq -c '.[]' $ARRAY | while read i; do
    echo $i | if jq .id;
      then
        echo $i | jq .id >> temp_workflow_ids.txt
      else
        echo skipping  
    fi
  done 
  
  sed 's/\"//g' temp_workflow_ids.txt >> workflow_ids.txt
}


#get workflows jobs # #https://circleci.com/docs/api/v2/#get-a-workflow-39-s-jobs
getJobInfo () {
  while IFS= read -r ENTRY; do
    WORKFLOW_API_CALL=`curl -u ${CIRCLE_TOKEN}: --header "Content-Type: application/json" -X GET "https://circleci.com/api/v2/pipeline/$ENTRY/workflow"`
    echo $WORKFLOW_API_CALL | jq .items | jq -c '.[]' $ARRAY | while read i; do
      echo $i | if jq .id;
        then 
          echo $i | jq .id >> temp_jobs.txt
        else
          echo "skipping"
      fi
    done
  done < workflow_ids.txt
  sed 's/\"//g' temp_jobs.txt >> job_info.txt
}


#get job numbers
getJobNumbers () {
  while IFS= read -r ENTRY; do
    JOB_API_CALL=`curl -u ${CIRCLE_TOKEN}: --header "Content-Type: application/json" -X GET "https://circleci.com/api/v2/workflow/$ENTRY/job"`
      echo $JOB_API_CALL | jq .items | jq -c '.[]' $ARRAY | while read i; do
       echo $i | if jq .job_number;
         then 
           echo $i | jq .job_number >> job_numbers.txt
         else
           echo no
       fi
    done
  done < job_info.txt
}

# get job numbers
getJobArtifacts () {
  touch digest-${CIRCLE_PROJECT_REPONAME}-${CIRCLE_BUILD-NUM}.txt
  while IFS= read -r ENTRY; do
  ARTIFACT_API_CALL=`curl -u ${CIRCLE_TOKEN}: --header "Content-Type: application/json" -X GET "https://circleci.com/api/v2/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$ENTRY/artifacts" \
      | grep -o 'https://[^"]*' \
      | wget --verbose --header "Circle-Token: $CIRCLE_TOKEN" --input-file -`
    $ARTIFACT_API_CALL 2>/dev/null
    if [ -f "memory.dat" ]; then
      rm digest.txt
      mkdir /tmp/digest-artifacts
      #check for artifact 
      echo "found matching artifact"
      percentage=$( tail -n 1 memory.dat )
      if [ $percentage \> $MAX_ACCEPTABLE ] || [ $MIN_ACCEPTABLE \> $percentage ];
      then 
        echo "job $ENTRY is using $percentage % of memory, and your threshold is between $MIN_ACCEPTABLE % and $MAX_ACCEPTABLE %" >> /tmp/digest-artifacts/digest-${CIRCLE_PROJECT_REPONAME}-${CIRCLE_BUILD_NUM}.txt
      else
        echo "usage within boundaries"
      fi
      rm memory.dat
    else 
      echo "skipping job, no artifact"
    fi
  done < job_numbers.txt
}

## function definitions - end ##

## beginning of script ##
installJQ
getWorkflowIds
getJobInfo
getJobNumbers
getJobArtifacts