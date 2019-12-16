# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

# the current working directory
cwd=$(pwd)

source "$dir/settings.sh"

# delete previous `API_GATEWAY_NAME` API gateways
aws apigateway get-rest-apis \
    --region $AWS_REGION \
    --query "items[?name=='$API_GATEWAY_NAME'].[id]" \
    --output text | while read id; do \
        aws apigateway delete-rest-api \
            --region $AWS_REGION \
            --rest-api-id "$id";
        echo "delete api-gateway-id: $id"
        echo 'deleting an API Gateway... (10 seconds required)'
        sleep 10;
    done

# create the API Gateway
echo -n 'api-gateway-id: '
aws apigateway create-rest-api \
    --region $AWS_REGION \
    --name $API_GATEWAY_NAME \
    --endpoint-configuration types=REGIONAL \
    --description 'A test API' \
    --query 'id' \
    --output text

# get the API Gateway id
API_GATEWAY_ID=$(aws apigateway get-rest-apis \
    --region $AWS_REGION \
    --query "items[?name=='$API_GATEWAY_NAME'].[id]" \
    --output text)

# write `API_GATEWAY_ID` into settings.sh
sed -i "s|API_GATEWAY_ID=.*$|API_GATEWAY_ID=$API_GATEWAY_ID|" "$dir/settings.sh"

# get the API Gateway arn 
API_GATEWAY_ARN="arn:aws:execute-api:${AWS_REGION}:${AWS_ID}:${API_GATEWAY_ID}"

# write `API_GATEWAY_ARN` into settings.sh
sed -i "s|API_GATEWAY_ARN=.*$|API_GATEWAY_ARN=$API_GATEWAY_ARN|" "$dir/settings.sh"

# get the root path id
API_GATEWAY_ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --query "items[?path=='/'].[id]" \
    --output text)

# write `API_GATEWAY_ROOT_RESOURCE_ID` into settings.sh
sed -i "s|API_GATEWAY_ROOT_RESOURCE_ID=.*$|API_GATEWAY_ROOT_RESOURCE_ID=$API_GATEWAY_ROOT_RESOURCE_ID|" "$dir/settings.sh"

# create the `API_GATEWAY_RESOURCE_NAME` resource path
echo -n 'api-gateway-resource-id: '
aws apigateway create-resource \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --parent-id $API_GATEWAY_ROOT_RESOURCE_ID \
    --path-part "$API_GATEWAY_RESOURCE_NAME" \
    --query 'id' \
    --output text

# get the `API_GATEWAY_RESOURCE_NAME` path id
API_GATEWAY_RESOURCE_ID=$(aws apigateway get-resources \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --query "items[?path=='/$API_GATEWAY_RESOURCE_NAME'].[id]" \
    --output text)

# write `API_GATEWAY_RESOURCE_ID` into settings.sh
sed -i "s|API_GATEWAY_RESOURCE_ID=.*$|API_GATEWAY_RESOURCE_ID=$API_GATEWAY_RESOURCE_ID|" "$dir/settings.sh"

# display the paths
echo -n 'api-gateway-resources: '
aws apigateway get-resources \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --query 'items[].{path:path, id:id}'

# create the POST method
echo -n 'put-method: '
aws apigateway put-method \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --resource-id $API_GATEWAY_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

# setup the POST method integration request
echo -n 'put-integration: '
aws apigateway put-integration \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --resource-id $API_GATEWAY_RESOURCE_ID \
    --http-method POST \
    --integration-http-method POST \
    --type AWS_PROXY \
    --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_FUNCTION_ARN/invocations"

# add lambda permission silently
STATEMENT_ID=api-lambda-permission-$(cat /dev/urandom | tr -dc 'a-z' | fold -w 10 | head -n 1)
echo "lambda add-permission statement-id: $STATEMENT_ID"
aws lambda add-permission \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME \
    --source-arn "$API_GATEWAY_ARN/*/POST/$API_GATEWAY_RESOURCE_NAME" \
    --principal apigateway.amazonaws.com \
    --statement-id $STATEMENT_ID \
    --action lambda:InvokeFunction &>/dev/null

# display the lambda policy
echo -n 'lambda get-policy: '
aws lambda get-policy \
    --region $AWS_REGION \
    --function-name $LAMBDA_FUNCTION_NAME \
    --query 'Policy' \
    --output text | jq --monochrome-output

# setup the POST method responses (method + integration response)
echo -n 'put-method-response: '
aws apigateway put-method-response \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --resource-id $API_GATEWAY_RESOURCE_ID \
    --http-method POST \
    --status-code 200 \
    --response-models '{"application/json": "Empty"}'

echo -n 'put-integration-response: '
aws apigateway put-integration-response \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --resource-id $API_GATEWAY_RESOURCE_ID \
    --http-method POST \
    --status-code 200 --selection-pattern ''

# publish the API, create the `dev` stage
echo -n 'create-deployment: '
aws apigateway create-deployment \
    --region $AWS_REGION \
    --rest-api-id $API_GATEWAY_ID \
    --stage-name dev

# test it
echo "curl --request POST https://$API_GATEWAY_ID.execute-api.$AWS_REGION.amazonaws.com/dev/$API_GATEWAY_RESOURCE_NAME"
curl --request POST https://$API_GATEWAY_ID.execute-api.$AWS_REGION.amazonaws.com/dev/$API_GATEWAY_RESOURCE_NAME