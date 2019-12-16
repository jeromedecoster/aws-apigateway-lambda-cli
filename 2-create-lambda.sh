# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

# the current working directory
cwd=$(pwd)

source "$dir/settings.sh"

previous=$(aws iam list-roles \
    --query "Roles[?RoleName=='$LAMBDA_ROLE_NAME'].RoleName" \
    --output text)

if [[ -n "$previous" ]]; then
    # to delete previous `LAMBDA_ROLE_NAME` role, you must detach policy first
    aws iam detach-role-policy \
        --role-name $LAMBDA_ROLE_NAME \
        --policy-arn $LAMBDA_POLICY_ARN 2>/dev/null

    # delete previous `LAMBDA_ROLE_NAME` role
    aws iam delete-role \
        --role-name $LAMBDA_ROLE_NAME
fi

# create the lambda role
echo -n 'create-role: '
cd "$dir"
aws iam create-role \
    --role-name $LAMBDA_ROLE_NAME \
    --assume-role-policy-document fileb://lambda-role-policy.json \
    --query 'Role.Arn' \
    --output text
cd "$cwd"

# get the lambda role Arn
LAMBDA_ROLE_ARN=$(aws iam get-role \
    --role-name $LAMBDA_ROLE_NAME \
    --query 'Role.Arn' \
    --output text)

# write `LAMBDA_ROLE_ARN` into settings.sh
sed -i "s|LAMBDA_ROLE_ARN=.*$|LAMBDA_ROLE_ARN=$LAMBDA_ROLE_ARN|" "$dir/settings.sh"

# display AWSLambdaBasicExecutionRole content
echo -n 'policy-arn: '
aws iam get-policy-version \
    --version-id v1 \
    --policy-arn $LAMBDA_POLICY_ARN

# attach the `AWSLambdaBasicExecutionRole` policy to the lambda role
aws iam attach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn $LAMBDA_POLICY_ARN

# display attached policies
echo -n 'attached-role-policies: '
aws iam list-attached-role-policies \
    --role-name $LAMBDA_ROLE_NAME \
    --query 'AttachedPolicies'

# need to wait for Arn to become available
echo 'waiting the availability of the iam role... (10 seconds required)'
sleep 10

# zip the code of the lambda function
echo 'create zip...'
cd "$dir"
rm --force lambda.zip
zip -9 lambda.zip index.js
cd "$cwd"

# delete previous `LAMBDA_FUNCTION_NAME` function 
aws lambda delete-function \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME 2>/dev/null

# create the `LAMBDA_FUNCTION_NAME` function
echo -n 'lambda-function-arn: '
cd "$dir"
aws lambda create-function \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime nodejs12.x \
    --role $LAMBDA_ROLE_ARN \
    --handler index.handler \
    --zip-file fileb://lambda.zip \
    --query 'FunctionArn' \
    --output text
cd "$cwd"

# get the lambda function Arn
LAMBDA_FUNCTION_ARN=$(aws lambda get-function \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME \
    --query 'Configuration.FunctionArn' \
    --output text)

# write `LAMBDA_FUNCTION_ARN` into settings.sh
sed -i "s|LAMBDA_FUNCTION_ARN=.*$|LAMBDA_FUNCTION_ARN=$LAMBDA_FUNCTION_ARN|" "$dir/settings.sh"