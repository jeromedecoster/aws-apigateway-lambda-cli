# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

# copy `settings.sample.sh` as `sample.sh` without overwriting
cp --no-clobber "$dir/settings.sample.sh" "$dir/settings.sh"

# get the AWS root account id
AWS_ID=$(aws sts get-caller-identity \
    --output text \
    --query 'Account')

# write `AWS_ID` into settings.sh
sed -i "s/AWS_ID=.*$/AWS_ID=$AWS_ID/" "$dir/settings.sh"