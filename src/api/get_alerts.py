import json
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('SecurityAlerts')

# Helper para que JSON pueda procesar los números (Decimal) de DynamoDB
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    try:
        # Hacemos Query usando la llave de partición que definimos
        response = table.query(
            KeyConditionExpression=Key('alert_status').eq('ACTIVE')
        )
        
        return {
            "statusCode": 200,
            "body": json.dumps(response.get('Items', []), cls=DecimalEncoder)
        }
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}