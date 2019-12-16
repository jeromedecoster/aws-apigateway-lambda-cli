# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

source "$dir/settings.sh"

# delete the API Gateway 
aws apigateway delete-rest-api \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID

# delete the Lambda
aws lambda delete-function \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME

# to delete the role, you must detach policy first
aws iam detach-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-arn $LAMBDA_POLICY_ARN

# delete the role
aws iam delete-role \
    --role-name $LAMBDA_ROLE_NAME