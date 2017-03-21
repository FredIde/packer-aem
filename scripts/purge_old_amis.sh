#!/bin/bash

AMI_ROLE_ARR=("soe AMI" "java AMI" "author AMI" "publish AMI" "dispatcher AMI")

for (( i=0; i < ${#AMI_ROLE_ARR[@]}; i++)); do
  echo "Processing images for application role \"${AMI_ROLE_ARR[$i]}\" .... "

  OLD_AMIS=$(aws ec2 describe-images --owner self \
         --filters "Name=tag:Application Id,Values=Adobe Experience Manager (AEM)"\
                    "Name=tag:Application Role,Values=${AMI_ROLE_ARR[$i]}" \
         --region ap-southeast-2 | jq -r '."Images"|sort_by(."Name")|.[0:-3]|.[]."ImageId"')

  if [ "${OLD_AMIS}EMPTY" = "EMPTY" ]; then
    echo "No stale images found for role \"${AMI_ROLE_ARR[$i]}\"."
    continue
  fi

  for OLD_AMI in $OLD_AMIS; do
    LCG_COUNT=$(aws autoscaling describe-launch-configurations \
               --query 'LaunchConfigurations[?ImageId==`'"$OLD_AMI"'`].LaunchConfigurationName' \
               --region ap-southeast-2 | jq 'length')
    LCG_COUNT="${LCG_COUNT:-0}"
    if [ "$LCG_COUNT" -gt 0 ]; then
      echo "Not deregistering image $OLD_AMI because it is still used by some launch configurations"
      continue
    fi

    RUNNING_COUNT=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"\
                      "Name=image-id,Values=$OLD_AMI" \
                   --query 'Reservations[].Instances[].InstanceId' \
                   --region ap-southeast-2 | jq 'flatten|length')
    RUNNING_COUNT="${RUNNING_COUNT:-0}"
    if [ "$RUNNING_COUNT" -gt 0 ]; then
      echo "Not deregistering image $OLD_AMI becuase it is still used by some runningn instances"
      continue
    fi
    echo -n "Deregistering staled image $OLD_AMI ...."
    aws ec2 deregister-image --image-id "$OLD_AMI" --region ap-southeast-2
    sleep 1
    echo "Done"
  done
done